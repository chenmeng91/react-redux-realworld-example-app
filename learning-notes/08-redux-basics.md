# 08. Redux 基础

这一部分对应 `LEARNING.md` 里的“Redux 基础”，同时融合了关于普通 Redux、Redux Toolkit、action creator、selector、slice 数据结构、`createSelector` 等追问。

主要参考文件：

- `src/app/store.js`
- `src/features/auth/authSlice.js`
- `src/reducers/common.js`
- `src/components/Header.js`
- `src/index.js`

## 1. Redux 解决什么问题

React 自己有 `useState`，适合组件内部状态。

例如登录页输入框：

```js
const [email, setEmail] = useState('');
```

这种状态只服务当前组件。

但有些状态很多组件都要用：

- 当前用户是谁
- 是否已登录
- token
- 当前文章
- 文章列表
- 评论列表
- 全局跳转状态
- 应用是否加载完成

如果用 props 一层层传，会很麻烦。

Redux 的作用是：

```text
把全局共享状态放到统一的 store 里
组件可以读取 store
组件可以通过 dispatch 触发状态变化
```

## 2. Redux 的核心概念

Redux 基础先记住这些概念：

```text
store：全局状态容器
state：当前应用状态
action：描述发生了什么
reducer：根据 action 更新 state
dispatch：发送 action
selector：从 state 中取数据
Provider：把 store 提供给 React
useSelector：组件读取 Redux state
useDispatch：组件发送 action
```

核心流程：

```text
组件
  -> dispatch(action)
  -> reducer(oldState, action)
  -> newState
  -> useSelector 读到新 state
  -> 组件重新渲染
```

## 3. store 是什么

`store` 是 Redux 的全局状态容器。

`src/app/store.js` 中：

```js
export function makeStore(preloadedState) {
  return configureStore({
    reducer: {
      article: articleReducer,
      articleList: articlesReducer,
      auth: authReducer,
      comments: commentsReducer,
      common: commonReducer,
      profile: profileReducer,
      tags: tagsReducer,
    },
    devTools: true,
    preloadedState,
    middleware: (getDefaultMiddleware) => [
      ...getDefaultMiddleware(),
      localStorageMiddleware,
    ],
  });
}

const store = makeStore();
```

`configureStore` 创建 Redux store。

最终全局 state 大概长这样：

```js
state = {
  article: ...,
  articleList: ...,
  auth: ...,
  comments: ...,
  common: ...,
  profile: ...,
  tags: ...
}
```

每一块 state 由对应 reducer 管理：

```js
auth: authReducer;
```

表示：

```text
state.auth 由 authReducer 管理
```

## 4. state 是什么

`state` 是当前应用状态。

例如登录前：

```js
state.auth = {
  status: Status.IDLE,
};
```

登录后可能变成：

```js
state.auth = {
  status: Status.SUCCESS,
  token: 'xxx',
  user: {
    username: 'tom',
    email: 'tom@example.com',
  },
};
```

Redux store 保存的是整个应用的状态树。

组件通过 `useSelector` 读取 state。

## 5. 如何看某个 slice 有哪些数据

看某个 slice 有哪些数据，主要看它的 `initialState`。

例如 `src/reducers/common.js`：

```js
const initialState = {
  appName: 'Conduit',
  appLoaded: false,
  viewChangeCounter: 0,
  redirectTo: undefined,
};
```

在 `store.js` 中：

```js
reducer: {
  common: commonReducer,
}
```

所以：

```js
state.common = {
  appName: 'Conduit',
  appLoaded: false,
  viewChangeCounter: 0,
  redirectTo: undefined,
};
```

但不能只看 `initialState`。

还要看 `reducers` 和 `extraReducers` 是否会新增或删除字段。

例如 `authSlice.js`：

```js
const initialState = {
  status: Status.IDLE,
};
```

初始只有：

```js
state.auth = {
  status: Status.IDLE,
};
```

但登录成功后：

```js
function successReducer(state, action) {
  state.status = Status.SUCCESS;
  state.token = action.payload.token;
  state.user = action.payload.user;
  delete state.errors;
}
```

运行时会有：

```js
state.auth.token;
state.auth.user;
```

总结方法：

```text
1. 看 store.js：确认 slice 挂在 state 的哪个 key 下
2. 看 import：找到 reducer 文件
3. 看 initialState：知道初始结构
4. 看 reducers / extraReducers：知道运行时会修改或新增哪些字段
5. 看 selectors：知道组件通常读取哪些字段
```

## 6. action 是什么

action 是一个普通对象，用来描述发生了什么。

例如：

```js
{
  type: 'auth/logout';
}
```

带数据的 action：

```js
{
  type: 'auth/setToken',
  payload: 'jwt.token.here'
}
```

登录成功的 action 类似：

```js
{
  type: 'auth/login/fulfilled',
  payload: {
    token: 'xxx',
    user: {...}
  }
}
```

action 本身不修改 state。

它只是描述：

```text
发生了什么
以及附带了什么数据
```

## 7. action creator 是什么

action creator 是创建 action 对象的函数。

如果每次都手写 action：

```js
dispatch({
  type: 'auth/setToken',
  payload: token,
});
```

容易重复，也容易写错 type。

所以可以封装成函数：

```js
function setToken(token) {
  return {
    type: 'auth/setToken',
    payload: token,
  };
}
```

这个函数就是 action creator。

使用：

```js
dispatch(setToken('abc'));
```

`setToken('abc')` 会返回：

```js
{
  type: 'auth/setToken',
  payload: 'abc'
}
```

所以：

```text
action 是事件对象
action creator 是创建事件对象的函数
```

在 Redux Toolkit 中，`createSlice` 会自动生成 action creator。

例如：

```js
reducers: {
  setToken(state, action) {
    state.token = action.payload;
  },
}
```

会生成：

```js
authSlice.actions.setToken;
```

## 8. reducer 是什么

reducer 是函数，用来根据 action 更新 state。

基础模型：

```text
旧 state + action -> 新 state
```

普通 Redux 中可能写成：

```js
function authReducer(state = initialState, action) {
  switch (action.type) {
    case 'auth/setToken':
      return {
        ...state,
        token: action.payload,
      };

    default:
      return state;
  }
}
```

Redux Toolkit 中可以写成：

```js
setToken(state, action) {
  state.token = action.payload;
}
```

看起来像直接修改 state，但 Redux Toolkit 内部使用 Immer，会生成新的 immutable state。

## 9. 普通 Redux 和 Redux Toolkit 的区别

Redux 是核心状态管理库。

Redux Toolkit 是 Redux 官方推荐的工具包。

它不是另一个完全不同的状态库，而是让 Redux 更好写。

普通 Redux 以前通常要手写：

```text
action type 常量
action creator
switch reducer
combineReducers
middleware 配置
不可变拷贝
```

例如普通 Redux：

```js
const SET_TOKEN = 'auth/setToken';

function setToken(token) {
  return {
    type: SET_TOKEN,
    payload: token,
  };
}

function authReducer(state = initialState, action) {
  switch (action.type) {
    case SET_TOKEN:
      return {
        ...state,
        token: action.payload,
      };

    default:
      return state;
  }
}
```

Redux Toolkit 使用 `createSlice`：

```js
const authSlice = createSlice({
  name: 'auth',
  initialState,
  reducers: {
    setToken(state, action) {
      state.token = action.payload;
    },
    logout: () => initialState,
  },
});
```

它自动生成：

```js
authSlice.actions.setToken;
authSlice.actions.logout;
authSlice.reducer;
```

对比：

```text
普通 Redux：
  手写 action type
  手写 action creator
  手写 reducer switch
  手动 return 新 state
  样板代码多

Redux Toolkit：
  createSlice 自动生成 action 和 reducer
  configureStore 自动配置 store
  createAsyncThunk 简化异步
  内置 Immer，可以写“修改式” reducer
  默认带常用 middleware
```

Redux Toolkit 没有改变 Redux 核心模型。

核心仍然是：

```text
dispatch(action)
  -> reducer 处理 action
  -> state 更新
  -> 组件重新渲染
```

## 10. createSlice 是什么

`createSlice` 用来创建 Redux 的一个状态模块。

`src/features/auth/authSlice.js`：

```js
const authSlice = createSlice({
  name: 'auth',
  initialState,
  reducers: {
    logout: () => initialState,
    setToken(state, action) {
      state.token = action.payload;
    },
  },
  extraReducers(builder) {
    ...
  },
});
```

`createSlice` 根据配置生成一个 slice 对象：

```js
authSlice = {
  name: 'auth',
  reducer,
  actions,
  caseReducers,
};
```

最重要的是：

```js
authSlice.reducer;
authSlice.actions;
```

所以：

```js
export const { setToken, logout } = authSlice.actions;
export default authSlice.reducer;
```

导出了：

```text
setToken / logout action creators
authSlice.reducer reducer
```

## 11. reducers 和 extraReducers

`reducers` 处理这个 slice 自己定义的 action：

```js
reducers: {
  logout: () => initialState,
  setToken(state, action) {
    state.token = action.payload;
  },
}
```

它会生成：

```js
logout();
setToken(token);
```

例如：

```js
setToken('abc');
```

生成：

```js
{
  type: 'auth/setToken',
  payload: 'abc'
}
```

`extraReducers` 处理外部 action。

例如：

```js
extraReducers(builder) {
  builder
    .addCase(login.fulfilled, successReducer)
    .addCase(register.fulfilled, successReducer)
    .addCase(getUser.fulfilled, successReducer);
}
```

`login.fulfilled` 是 `createAsyncThunk` 生成的 action，不是 `authSlice.actions` 中定义的普通 action。

但 `authReducer` 也需要响应它，所以放在 `extraReducers`。

## 12. dispatch 是什么

dispatch 是发送 action 的方法。

组件中通过：

```js
const dispatch = useDispatch();
```

拿到 dispatch。

使用：

```js
dispatch(logout());
dispatch(setToken(token));
```

流程：

```text
dispatch(action)
  -> Redux store 收到 action
  -> 调用 reducer
  -> reducer 根据 action 计算新 state
  -> store 更新
  -> 订阅这个 state 的组件重新渲染
```

## 13. useSelector 是什么

`useSelector` 用来从 Redux state 中读取数据。

`src/components/Header.js`：

```js
const isAuthenticated = useSelector(selectIsAuthenticated);
const appName = useSelector((state) => state.common.appName);
```

意思是：

```text
从 Redux store 中读取登录状态
从 Redux store 中读取 appName
```

如果读取到的值变化，组件会重新渲染。

例如：

```text
登录成功
  -> state.auth.token 和 state.auth.user 有值
  -> selectIsAuthenticated 从 false 变 true
  -> Header 重新渲染
  -> 显示 LoggedInNavbar
```

## 14. `useSelector((state) => state.common.appName)` 中的 state 是什么

代码：

```js
const appName = useSelector((state) => state.common.appName);
```

这里的：

```js
(state) => state.common.appName;
```

是一个 selector 函数。

`state` 是 Redux store 的完整全局状态树。

由 `store.js` 中的 reducer 配置决定：

```js
state = {
  article: ...,
  articleList: ...,
  auth: ...,
  comments: ...,
  common: {
    appName: 'Conduit',
    appLoaded: false,
    viewChangeCounter: 0,
    redirectTo: undefined,
  },
  profile: ...,
  tags: ...
}
```

所以：

```js
state.common.appName;
```

就是：

```js
'Conduit';
```

`state` 不是你手动传进去的。

`useSelector` 内部会从 Redux store 调用：

```js
store.getState();
```

然后把完整 state 传给 selector。

## 15. selector 是什么

selector 是一个从 state 中取数据或计算数据的函数。

简单 selector：

```js
const selectAuthSlice = (state) => state.auth;
```

读取 user：

```js
export const selectUser = (state) => selectAuthSlice(state).user;
```

读取 loading：

```js
export const selectIsLoading = (state) =>
  selectAuthSlice(state).status === Status.LOADING;
```

selector 的好处：

```text
组件不用知道 state 具体结构
复杂计算可以集中管理
多个组件可以复用同一套读取逻辑
```

## 16. createSelector 是什么

`createSelector` 是一个函数，来自 `reselect`，Redux Toolkit 也重新导出了它。

它用来创建带缓存能力的 selector。

常见形式：

```js
createSelector(inputSelector1, inputSelector2, resultFunc);
```

也可以写数组形式：

```js
createSelector([inputSelector1, inputSelector2], resultFunc);
```

前面是若干输入 selector，最后一个是结果计算函数。

## 17. `selectIsAuthenticated` 代码讲解

`authSlice.js`：

```js
export const selectIsAuthenticated = createSelector(
  (state) => selectAuthSlice(state).token,
  selectUser,
  (token, user) => Boolean(token && user)
);
```

第一个输入 selector：

```js
(state) => selectAuthSlice(state).token;
```

等价于：

```js
state.auth.token;
```

第二个输入 selector：

```js
selectUser;
```

等价于：

```js
state.auth.user;
```

最后的结果函数：

```js
(token, user) => Boolean(token && user);
```

含义：

```text
token 有值，并且 user 有值 -> true
否则 -> false
```

它是一个派生 selector：

```text
从 state.auth.token 和 state.auth.user
计算出用户是否已登录
```

在 `Header.js` 中使用：

```js
const isAuthenticated = useSelector(selectIsAuthenticated);
```

然后：

```jsx
{
  isAuthenticated ? <LoggedInNavbar /> : <LoggedOutNavbar />;
}
```

## 18. createSelector 的类型声明为什么复杂

你看到的 `.d.ts` 中：

```ts
export declare const createSelector: CreateSelectorFunction<
  (...args: unknown[]) => unknown,
  typeof defaultMemoize,
  [equalityCheckOrOptions?: EqualityFn | DefaultMemoizeOptions | undefined],
  {
    clearCache: () => void;
  }
>;
```

这是 TypeScript 类型声明，不是运行时代码。

简化看：

```ts
export declare const createSelector: CreateSelectorFunction<...>;
```

意思是：

```text
createSelector 是一个函数
它的具体调用签名由 CreateSelectorFunction 这个类型描述
```

泛型参数表达的是：

- selector 可以接收任意参数
- 默认使用 `defaultMemoize` 做缓存
- 可以接收 equality function 或 options
- 返回的 selector 可能有 `clearCache()` 方法

业务开发时不用先读懂整段类型。

常用写法记住即可：

```js
createSelector(inputSelectors..., resultFunc)
```

## 19. React-Redux 是什么

Redux 本身和 React 没有直接关系。

React-Redux 是连接 Redux 和 React 的库。

`src/index.js`：

```jsx
<Provider store={store}>
  <Router>
    <App />
  </Router>
</Provider>
```

`Provider` 把 Redux store 放进 React Context。

这样子组件才能用：

```js
useSelector();
useDispatch();
```

关系：

```text
Redux store：保存全局状态
React：负责渲染 UI
React-Redux：把 store 接入 React 组件
```

## 20. 一次 Redux 状态更新流程

以登录成功后 Header 变化为例：

```text
用户提交登录
  -> dispatch(login({ email, password }))
  -> 登录请求成功
  -> dispatch auth/login/fulfilled
  -> authReducer 匹配 login.fulfilled
  -> successReducer 修改 state.auth.token/user
  -> Redux store 更新
  -> Header 的 useSelector(selectIsAuthenticated) 发现结果变了
  -> Header 重新渲染
  -> 显示 LoggedInNavbar
```

同步 action 的流程类似：

```text
dispatch(logout())
  -> logout action type 是 auth/logout
  -> authReducer 处理 logout
  -> state.auth 回到 initialState
  -> Header 重新渲染
  -> 显示 LoggedOutNavbar
```

## 21. createAsyncThunk 放在哪一节

`createAsyncThunk` 属于 Redux Toolkit 的异步状态管理工具。

它会在第 9 部分“异步状态管理”重点讲。

第 8 部分 Redux 基础先重点掌握：

```text
store
state
action
reducer
dispatch
selector
createSlice
React-Redux
```

第 9 部分再系统讲：

```text
createAsyncThunk
pending / fulfilled / rejected
loading / errors
rejectWithValue
condition
```

## 22. 本节重点

Redux 基础最终可以压缩成这张图：

```text
组件
  -> useDispatch 拿到 dispatch
  -> dispatch(action)
  -> reducer(oldState, action)
  -> newState
  -> useSelector 读到新 state
  -> 组件重新渲染
```

关键结论：

```text
1. Redux 用 store 保存全局状态。
2. action 描述发生了什么。
3. reducer 根据 action 更新 state。
4. dispatch 用来发送 action。
5. selector 用来从 state 取数据。
6. useSelector 会订阅 selector 的结果变化。
7. Redux Toolkit 是 Redux 官方工具包，减少样板代码。
8. createSlice 会生成 reducer 和 action creators。
9. createSelector 用来写带缓存的派生 selector。
10. React-Redux 用 Provider/useSelector/useDispatch 把 Redux 接入 React。
```
