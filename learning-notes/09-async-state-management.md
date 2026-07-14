# 09. 异步状态管理

这一部分对应 `LEARNING.md` 里的“异步状态管理”，同时融合关于 `createAsyncThunk`、thunk 函数、`condition`、pending/fulfilled/rejected、评论乐观更新、`dispatch(...).then()`、`.catch()`、`.unwrap()`、以及 Redux Toolkit 源码执行顺序的追问。

主要参考文件：

- `src/features/auth/authSlice.js`
- `src/features/auth/AuthScreen.js`
- `src/features/comments/commentsSlice.js`
- `src/features/comments/CommentSection.js`
- `src/features/tags/tagsSlice.js`
- `src/common/utils.js`
- `node_modules/@reduxjs/toolkit/src/createAsyncThunk.ts`
- `node_modules/redux-thunk/src/index.ts`
- `node_modules/redux/src/createStore.js`

## 1. 什么是异步状态管理

同步状态变化很好理解：

```text
点击按钮
  -> dispatch 一个普通 action
  -> reducer 立刻修改 state
  -> 页面重新渲染
```

但接口请求不是立刻完成的。一次请求通常有三个阶段：

```text
请求开始：pending
请求成功：fulfilled
请求失败：rejected
```

Redux Toolkit 的 `createAsyncThunk` 就是用来标准化这三个阶段的。

它不是 React 的能力，也不是 React-Redux 的能力，而是 Redux Toolkit 提供的异步 action 工具。

## 2. createAsyncThunk 创建的是什么

以登录为例，`src/features/auth/authSlice.js` 中：

```js
export const login = createAsyncThunk(
  'auth/login',
  async ({ email, password }, thunkApi) => {
    try {
      const {
        user: { token, ...user },
      } = await agent.Auth.login(email, password);

      return { token, user };
    } catch (error) {
      if (isApiError(error)) {
        return thunkApi.rejectWithValue(error);
      }

      throw error;
    }
  },
  {
    condition: (_, { getState }) => !selectIsLoading(getState()),
  }
);
```

`createAsyncThunk(...)` 返回的是一个 action creator，项目里叫 `login`。

所以 `login` 是函数。

调用它：

```js
login({ email, password });
```

返回的不是普通 action 对象，而是一个 thunk 函数。

也就是概念上类似：

```js
function thunk(dispatch, getState, extra) {
  // 内部先 dispatch pending
  // 再执行异步请求
  // 最后 dispatch fulfilled 或 rejected
}
```

所以：

```js
dispatch(login({ email, password }));
```

可以理解成：

```js
const thunkAction = login({ email, password });
dispatch(thunkAction);
```

## 3. thunk 函数是什么意思

thunk 函数在 Redux 里通常指：

```text
可以被 dispatch 的函数
```

普通 Redux 的 `dispatch` 默认只能接收普通对象：

```js
dispatch({
  type: 'auth/logout',
});
```

但这个项目用的是 Redux Toolkit 的 `configureStore`，默认包含 `redux-thunk` middleware。

`redux-thunk` 的核心源码在 `node_modules/redux-thunk/src/index.ts`：

```ts
const middleware =
  ({ dispatch, getState }) =>
  (next) =>
  (action) => {
    if (typeof action === 'function') {
      return action(dispatch, getState, extraArgument);
    }

    return next(action);
  };
```

意思是：

```text
如果 dispatch 的东西是函数，就执行这个函数
如果 dispatch 的东西不是函数，就继续按普通 action 处理
```

所以 `dispatch(login(...))` 能工作，是因为 `login(...)` 返回的是函数，而 thunk middleware 会执行它。

不是任何函数都“自然就是 Redux thunk”。更准确地说：

```text
任何函数都可以被 thunk middleware 接收并执行
但有意义的 thunk 一般需要接收 dispatch/getState，并在内部 dispatch action
```

例如这是一个有意义的 thunk：

```js
function loadUser() {
  return async function thunk(dispatch, getState) {
    const user = await api.getUser();
    dispatch({ type: 'user/loaded', payload: user });
  };
}
```

## 4. pending、fulfilled、rejected action type 如何确定

`createAsyncThunk` 的第一个参数叫 `typePrefix`。

登录这里是：

```js
'auth/login';
```

Redux Toolkit 会基于它自动生成三个 action type：

```text
auth/login/pending
auth/login/fulfilled
auth/login/rejected
```

评论创建这里：

```js
createAsyncThunk('comments/createComment', ...)
```

会生成：

```text
comments/createComment/pending
comments/createComment/fulfilled
comments/createComment/rejected
```

所以这些字符串不是业务代码手写出来的，而是 Redux Toolkit 按规则拼出来的。

## 5. createAsyncThunk 内部做了什么

源码在 `node_modules/@reduxjs/toolkit/src/createAsyncThunk.ts`。

核心片段：

```ts
function actionCreator(arg) {
  return (dispatch, getState, extra) => {
    const requestId = options?.idGenerator
      ? options.idGenerator(arg)
      : nanoid();

    const promise = (async function () {
      let finalAction;

      try {
        let conditionResult = options?.condition?.(arg, { getState, extra });

        if (conditionResult === false) {
          throw {
            name: 'ConditionError',
            message: 'Aborted due to condition callback returning false.',
          };
        }

        dispatch(
          pending(
            requestId,
            arg,
            options?.getPendingMeta?.({ requestId, arg }, { getState, extra })
          )
        );

        finalAction = await Promise.resolve(
          payloadCreator(arg, {
            dispatch,
            getState,
            extra,
            requestId,
            rejectWithValue,
            fulfillWithValue,
          })
        ).then((result) => {
          return fulfilled(result, requestId, arg);
        });
      } catch (err) {
        finalAction = rejected(err, requestId, arg);
      }

      dispatch(finalAction);
      return finalAction;
    })();

    return promise;
  };
}
```

这是简化后的关键逻辑。真实源码还处理了 abort、`RejectWithValue`、`FulfillWithMeta` 等细节。

核心顺序是：

```text
login(arg)
  -> 返回 thunk 函数
dispatch(thunk 函数)
  -> thunk middleware 执行 thunk
  -> createAsyncThunk 检查 condition
  -> dispatch pending action
  -> await payloadCreator，也就是执行接口请求
  -> 成功生成 fulfilled action
  -> 失败生成 rejected action
  -> dispatch fulfilled/rejected action
  -> return finalAction
```

## 6. 真正修改 state 的地方在哪里

`createAsyncThunk` 本身不直接修改 Redux state。

它只负责：

```text
生成 pending/fulfilled/rejected action
并把这些 action dispatch 出去
```

真正修改 state 的地方是 slice 里的 reducer。

登录成功时，在 `src/features/auth/authSlice.js` 中：

```js
builder
  .addCase(login.fulfilled, successReducer)
  .addCase(register.fulfilled, successReducer)
  .addCase(getUser.fulfilled, successReducer)
  .addCase(updateUser.fulfilled, successReducer);
```

其中：

```js
function successReducer(state, action) {
  state.status = Status.SUCCESS;
  state.token = action.payload.token;
  state.user = action.payload.user;
  delete state.errors;
}
```

所以登录成功后，真正把 `token` 和 `user` 写进 Redux state 的是 `successReducer`。

登录失败时：

```js
builder
  .addCase(login.rejected, failureReducer)
  .addCase(register.rejected, failureReducer)
  .addCase(updateUser.rejected, failureReducer);
```

`failureReducer` 在 `src/common/utils.js`：

```js
export function failureReducer(state, action) {
  state.status = Status.FAILURE;
  state.errors = action.payload.errors;
}
```

所以错误信息进入 Redux state 的地方是 `failureReducer`。

## 7. loading 状态如何进入 Redux state

`src/common/utils.js` 里定义了公共状态值：

```js
export const Status = {
  IDLE: 'idle',
  LOADING: 'loading',
  SUCCESS: 'success',
  FAILURE: 'failure',
};
```

不同 slice 里都有自己的 `status` 字段。

例如：

```js
state.auth.status;
state.comments.status;
state.tags.status;
```

它们不是同一个对象，也不是同一个字段。它们只是都使用了同一套状态值规范：

```js
Status.IDLE;
Status.LOADING;
Status.SUCCESS;
Status.FAILURE;
```

登录的 pending 状态通过 matcher 处理：

```js
builder.addMatcher(
  (action) => /auth\/.*\/pending/.test(action.type),
  loadingReducer
);
```

`loadingReducer`：

```js
export function loadingReducer(state) {
  state.status = Status.LOADING;
}
```

所以任何 `auth/.../pending` action 都会让：

```js
state.auth.status = 'loading';
```

这就是登录按钮能 disabled 的原因之一。

## 8. condition 为什么不放在点击事件里拦截

登录里有：

```js
condition: (_, { getState }) => !selectIsLoading(getState());
```

评论里有：

```js
condition: (_, { getState }) =>
  selectIsAuthenticated(getState()) && !selectIsLoading(getState());
```

`condition` 的作用是在 thunk 真正执行前做统一拦截。

它比写在点击事件里更靠近异步动作本身。

如果只在点击事件里写：

```js
if (inProgress) return;
dispatch(login(...));
```

只能拦住这个组件里的点击。

但同一个 thunk 可能从很多地方被调用：

```js
dispatch(login(...))
dispatch(createComment(...))
dispatch(getCommentsForArticle(...))
```

放在 `condition` 里，任何地方 dispatch 这个 thunk，都会统一检查。

所以它适合做：

```text
防止重复请求
未登录不允许请求
当前状态不满足时不发请求
```

## 9. appLoad(token) 为什么可以 dispatch

前面提到，Redux Toolkit 默认带 thunk middleware。

所以除了 `createAsyncThunk` 生成的 thunk，普通手写 thunk 也可以 dispatch。

例如 `appLoad(token)` 这种形式，通常是：

```js
function appLoad(token) {
  return function thunk(dispatch, getState) {
    agent.setToken(token);
    dispatch(setToken(token));
    dispatch(getUser());
  };
}
```

所以：

```js
dispatch(appLoad(token));
```

本质也是：

```text
dispatch 一个函数
  -> thunk middleware 发现是函数
  -> 执行这个函数
  -> 函数内部可以继续 dispatch 其他 action/thunk
```

这也是为什么应用启动时可以：

```text
读取 localStorage 里的 jwt
  -> appLoad(token)
  -> agent.setToken(token)
  -> dispatch(setToken(token))
  -> dispatch(getUser())
```

这里的 `setToken(token)` 是普通 action。

`getUser()` 是 `createAsyncThunk` 生成的 thunk。

## 10. dispatch(login(...)).then 的执行顺序

登录页 `src/features/auth/AuthScreen.js` 中：

```js
dispatch(
  isRegisterScreen
    ? register({ username, email, password })
    : login({ email, password })
).then((action) => {
  if (action.meta.requestStatus === 'rejected') {
    return;
  }
  if (isRegisterScreen) {
    navigate('/login');
  } else {
    navigate('/');
  }
});
```

这里 `.then((action) => {})` 里的函数是在对应 `addCase` reducer 执行之后才执行。

源码关键点在 `createAsyncThunk.ts`：

```ts
if (!skipDispatch) {
  dispatch(finalAction);
}

return finalAction;
```

顺序是：

```text
请求成功
  -> 生成 auth/login/fulfilled
  -> dispatch(finalAction)
  -> Redux reducer 执行
  -> addCase(login.fulfilled, successReducer) 执行
  -> state.auth.token 和 state.auth.user 已经更新
  -> return finalAction
  -> dispatch(login(...)) 返回的 Promise resolve
  -> then(action => {}) 执行
```

失败时也类似：

```text
请求失败
  -> 生成 auth/login/rejected
  -> dispatch(finalAction)
  -> addCase(login.rejected, failureReducer) 执行
  -> state.auth.errors 已经更新
  -> return finalAction
  -> then(action => {}) 执行
```

所以 `.then` 不是监听 reducer。

它只是等 `dispatch(login(...))` 返回的 Promise 完成。

而这个 Promise 的 resolve 时机由 `createAsyncThunk` 控制。

## 11. dispatch 普通 action 时 Redux 如何触发 reducer

Redux 原始源码在 `node_modules/redux/src/createStore.js`：

```js
function dispatch(action) {
  try {
    isDispatching = true;
    currentState = currentReducer(currentState, action);
  } finally {
    isDispatching = false;
  }

  const listeners = (currentListeners = nextListeners);
  for (let i = 0; i < listeners.length; i++) {
    const listener = listeners[i];
    listener();
  }

  return action;
}
```

核心是：

```js
currentState = currentReducer(currentState, action);
```

所以 `dispatch(finalAction)` 会同步调用当前 reducer。

Redux Toolkit 的 `createReducer` 会根据 `action.type` 找到对应 case reducer：

```ts
let caseReducers = [
  actionsMap[action.type],
  ...finalActionMatchers
    .filter(({ matcher }) => matcher(action))
    .map(({ reducer }) => reducer),
];
```

然后执行：

```ts
const result = caseReducer(draft, action);
```

所以项目里的：

```js
.addCase(login.fulfilled, successReducer)
```

本质上就是注册：

```js
actionsMap['auth/login/fulfilled'] = successReducer;
```

当 action type 是 `auth/login/fulfilled` 时，就会执行 `successReducer`。

## 12. then 里的 action 字段哪些是规定的，哪些是业务的

这里：

```js
action.meta.requestStatus === 'rejected';
```

字段来源如下：

```text
action：Redux action 对象
meta：Redux Toolkit / FSA 风格字段
requestStatus：createAsyncThunk 自动生成的字段
'rejected'：createAsyncThunk 自动生成的状态值
```

Redux 原生只强制 action 至少有：

```js
{
  type: string;
}
```

`meta.requestStatus` 不是 Redux 原生规定的，而是 Redux Toolkit 的 `createAsyncThunk` 生成的。

`createAsyncThunk` 的状态值有三个：

```js
'pending';
'fulfilled';
'rejected';
```

业务字段通常在：

```js
action.meta.arg;
action.payload;
action.payload.errors;
```

例如登录时：

```js
action.meta.arg;
```

大概是：

```js
{
  email: 'xxx',
  password: 'xxx'
}
```

成功时：

```js
action.payload;
```

大概是：

```js
{
  token: 'xxx',
  user: {
    email: 'xxx',
    username: 'xxx'
  }
}
```

这里的 `email`、`password`、`token`、`user` 才是业务字段。

## 13. then 后面加 catch 语法正确吗

语法正确：

```js
dispatch(login({ email, password }))
  .then((action) => {
    if (action.meta.requestStatus === 'rejected') {
      return;
    }

    navigate('/');
  })
  .catch((error) => {
    // 语法上可以写
  });
```

但对于 `createAsyncThunk` 来说，普通请求失败一般不会进入这个 `catch`。

因为：

```js
dispatch(login(...))
```

返回的 Promise 默认会 resolve 一个 action。

成功时 resolve：

```text
auth/login/fulfilled action
```

失败时也 resolve：

```text
auth/login/rejected action
```

所以请求失败通常走：

```js
.then((action) => {
  if (action.meta.requestStatus === 'rejected') {
    return;
  }
})
```

如果希望失败进入 `catch`，要使用 `.unwrap()`：

```js
dispatch(login({ email, password }))
  .unwrap()
  .then((payload) => {
    navigate('/');
  })
  .catch((error) => {
    // rejected 时会进入这里
  });
```

区别是：

```text
dispatch(thunk).then(action)
  -> 成功失败都进入 then
  -> 需要自己判断 action.meta.requestStatus

dispatch(thunk).unwrap().then(payload).catch(error)
  -> 成功进入 then，拿到 payload
  -> 失败进入 catch
```

## 14. 评论 pending 阶段为什么能先插入列表

评论提交在 `src/features/comments/CommentSection.js`：

```js
const [body, setBody] = useState('');

const saveComment = (event) => {
  event.preventDefault();
  dispatch(createComment({ articleSlug: slug, comment: { body } }));
  setBody('');
};
```

这里用户输入的评论内容被放进：

```js
comment: {
  body;
}
```

然后传给：

```js
createComment({ articleSlug: slug, comment: { body } });
```

`createComment` 定义在 `src/features/comments/commentsSlice.js`：

```js
export const createComment = createAsyncThunk(
  'comments/createComment',
  async ({ articleSlug, comment: newComment }, thunkApi) => {
    try {
      const { comment } = await agent.Comments.create(articleSlug, newComment);

      return comment;
    } catch (error) {
      if (isApiError(error)) {
        return thunkApi.rejectWithValue(error);
      }

      throw error;
    }
  },
  {
    condition: (_, { getState }) =>
      selectIsAuthenticated(getState()) && !selectIsLoading(getState()),
    getPendingMeta: (_, { getState }) => ({ author: selectUser(getState()) }),
  }
);
```

重点是：

```js
getPendingMeta: (_, { getState }) => ({ author: selectUser(getState()) });
```

`getPendingMeta` 是一个箭头函数。

它会在 pending action 生成前执行，并把返回值合并进 `action.meta`。

所以 pending action 里会有：

```js
action.meta.author;
```

这个 `author` 来自当前 Redux state 里的登录用户：

```js
selectUser(getState());
```

评论 pending reducer：

```js
.addCase(createComment.pending, (state, action) => {
  state.status = Status.LOADING;

  if (action.meta.arg.comment.body) {
    commentAdapter.addOne(state, {
      ...action.meta.arg.comment,
      author: action.meta.author,
      id: action.meta.requestId,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    });
  }
})
```

这里临时评论的数据来源是：

```text
action.meta.arg.comment.body
  -> 来自 dispatch(createComment({ comment: { body } }))

action.meta.author
  -> 来自 getPendingMeta 返回的 author

action.meta.requestId
  -> createAsyncThunk 自动生成的请求 id

createdAt / updatedAt
  -> 前端在 pending reducer 里用当前时间生成
```

拼出来的临时评论大概是：

```js
{
  body: '用户输入的评论',
  author: 当前登录用户,
  id: '自动生成的 requestId',
  createdAt: '当前时间',
  updatedAt: '当前时间'
}
```

真正把它插入 Redux state 的是：

```js
commentAdapter.addOne(state, temporaryComment);
```

这叫乐观更新：

```text
请求还没成功
先把评论临时显示到列表里
```

## 15. 评论成功或失败后如何处理临时数据

请求成功后：

```js
.addCase(createComment.fulfilled, (state, action) => {
  state.status = Status.SUCCESS;
  commentAdapter.updateOne(state, {
    id: action.meta.requestId,
    changes: action.payload,
  });
  delete state.errors;
})
```

这里用同一个：

```js
action.meta.requestId;
```

找到 pending 阶段插入的临时评论，然后用后端返回的真实评论更新它：

```js
changes: action.payload;
```

请求失败后：

```js
.addCase(createComment.rejected, (state, action) => {
  state.status = Status.FAILURE;
  state.errors = action.payload?.errors;
  commentAdapter.removeOne(state, action.meta.requestId);
});
```

失败时用同一个 `requestId` 删除临时评论。

所以完整流程是：

```text
用户输入评论
  -> dispatch(createComment({ articleSlug, comment: { body } }))
  -> createAsyncThunk 生成 requestId
  -> getPendingMeta 从 Redux state 拿当前 user
  -> pending reducer 用 body + author + requestId 拼临时评论
  -> commentAdapter.addOne 立刻插入列表
  -> 请求成功
      -> fulfilled reducer 用服务器返回数据更新临时评论
  -> 请求失败
      -> rejected reducer 删除临时评论
```

## 16. createEntityAdapter 在这里的作用

评论 slice 使用了：

```js
const commentAdapter = createEntityAdapter({
  sortComparer: (a, b) => b.createdAt.localeCompare(a.createdAt),
});
```

它会把评论列表管理成规范化结构：

```js
{
  ids: [1, 2, 3],
  entities: {
    1: { id: 1, body: '...' },
    2: { id: 2, body: '...' },
    3: { id: 3, body: '...' }
  },
  status: 'idle'
}
```

所以：

```js
commentAdapter.addOne(state, comment);
```

不是简单 `array.push`，而是会维护：

```js
state.ids;
state.entities;
```

因为设置了 `sortComparer`，评论还会按 `createdAt` 排序。

## 17. 异步状态管理的核心模型

以后看到任何 `createAsyncThunk`，都可以按这个模型看：

```text
1. 找 createAsyncThunk 的 typePrefix
   -> 知道 pending/fulfilled/rejected 的 action type

2. 看 payloadCreator
   -> 知道真正请求哪个 API
   -> 知道成功时 return 什么 payload
   -> 知道失败时 rejectWithValue 什么错误

3. 看 options
   -> condition 是否阻止请求
   -> getPendingMeta 是否给 pending action 增加额外 meta

4. 看 extraReducers
   -> pending 如何改 loading
   -> fulfilled 如何写入成功数据
   -> rejected 如何写入错误数据

5. 看组件 dispatch
   -> 谁触发这个 thunk
   -> 传入的 arg 是什么
   -> then/unwrap 后做什么跳转或后续动作
```

一句话总结：

```text
createAsyncThunk 管异步 action 的生命周期
redux-thunk 让 dispatch 可以接收函数
slice extraReducers 负责真正修改 Redux state
React-Redux 负责把 state 变化反映到组件重新渲染
```
