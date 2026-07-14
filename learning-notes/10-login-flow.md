# 10. 登录流程完整拆解

这一部分对应 `LEARNING.md` 里的“登录流程完整拆解”，同时融合关于表单校验、`...user` 解构语法、Redux middleware 是否类似 HTTP 拦截器、middleware 在 state 修改前还是之后执行、以及请求 header 应该在哪里增加的追问。

主要参考文件：

- `src/components/App.js`
- `src/features/auth/AuthScreen.js`
- `src/features/auth/authSlice.js`
- `src/agent.js`
- `src/app/middleware.js`
- `src/app/store.js`
- `src/components/Header.js`
- `src/reducers/common.js`

## 1. 登录页是怎么被渲染出来的

登录页不是浏览器重新下载一个 HTML 页面，而是 React Router 根据当前路径渲染对应组件。

`src/components/App.js` 中：

```jsx
<Route path="/login" element={<AuthScreen />} />
<Route path="/register" element={<AuthScreen isRegisterScreen />} />
```

所以：

```text
访问 /login
  -> 渲染 <AuthScreen />

访问 /register
  -> 渲染 <AuthScreen isRegisterScreen />
```

`isRegisterScreen` 是传给 `AuthScreen` 的 props。

它用来区分当前是登录页还是注册页。

## 2. AuthScreen 中的表单状态

`src/features/auth/AuthScreen.js` 中：

```js
function AuthScreen({ isRegisterScreen }) {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [email, setEmail] = useState('');
  const dispatch = useDispatch();
  const errors = useSelector(selectErrors);
  const inProgress = useSelector(selectIsLoading);
  const navigate = useNavigate();
}
```

这里分两类状态：

```text
React 局部状态：
  username
  email
  password

Redux 全局状态：
  errors
  inProgress
```

输入框里的内容属于当前页面表单，所以用 `useState`。

接口错误、请求中状态属于认证模块，所以从 Redux 里读取。

## 3. 输入框如何更新状态

例如 email：

```js
const changeEmail = (event) => {
  setEmail(event.target.value);
};
```

对应输入框：

```jsx
<input type="email" value={email} onChange={changeEmail} />
```

流程是：

```text
用户输入 email
  -> input 触发 onChange
  -> changeEmail(event)
  -> setEmail(event.target.value)
  -> AuthScreen 重新渲染
  -> input value 更新
```

这就是 React 里的受控组件。

## 4. 提交表单时发生什么

`AuthScreen.js` 中：

```js
const authenticateUser = (event) => {
  event.preventDefault();
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
};
```

核心流程：

```text
用户点击 Sign in
  -> form onSubmit
  -> authenticateUser
  -> event.preventDefault()
  -> dispatch(login({ email, password }))
```

`event.preventDefault()` 用来阻止浏览器的默认表单提交。

如果不阻止，浏览器会尝试按传统表单方式提交并刷新页面。

## 5. 是否需要验证 username/email/password 不为空

真实项目里应该做。

当前 demo 主要依赖后端校验，所以代码里没有在 `authenticateUser` 里提前判断：

```js
email 是否为空
password 是否为空
email 格式是否合法
注册时 username 是否为空
```

当前项目的流程是：

```text
空值也会请求接口
  -> 后端返回错误
  -> login/register 进入 rejected
  -> failureReducer 写入 state.auth.errors
  -> ListErrors 显示错误
```

真实项目通常会有两层校验：

```text
前端基础校验：
  必填
  email 格式
  password 长度
  注册 username 必填

后端权威校验：
  账号是否存在
  密码是否正确
  email 是否已注册
  username 是否已占用
```

前端校验不是替代后端校验，而是为了更快给用户反馈、减少无效请求。

最小校验可以类似：

```js
const authenticateUser = (event) => {
  event.preventDefault();

  if (!email.trim()) {
    return;
  }

  if (!password.trim()) {
    return;
  }

  if (isRegisterScreen && !username.trim()) {
    return;
  }

  dispatch(
    isRegisterScreen
      ? register({ username, email, password })
      : login({ email, password })
  );
};
```

不过这样只是阻止提交，还没有显示具体错误。

更完整的做法一般是增加本地表单错误 state，或者使用表单库。

## 6. login 是什么

`src/features/auth/authSlice.js` 中：

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

`login` 是 `createAsyncThunk` 创建出来的 action creator。

调用：

```js
login({ email, password });
```

会得到一个 thunk 函数。

然后：

```js
dispatch(login({ email, password }));
```

会由 thunk middleware 执行这个 thunk。

这个 thunk 会自动发出：

```text
auth/login/pending
auth/login/fulfilled
auth/login/rejected
```

## 7. pending 阶段：进入 loading

请求开始前，`createAsyncThunk` 会先发出：

```text
auth/login/pending
```

`authSlice.js` 中：

```js
builder.addMatcher(
  (action) => /auth\/.*\/pending/.test(action.type),
  loadingReducer
);
```

`loadingReducer` 会把：

```js
state.auth.status = Status.LOADING;
```

然后 `AuthScreen` 里：

```js
const inProgress = useSelector(selectIsLoading);
```

`selectIsLoading`：

```js
export const selectIsLoading = (state) =>
  selectAuthSlice(state).status === Status.LOADING;
```

表单里：

```jsx
<fieldset disabled={inProgress}>
```

所以 pending 阶段表单会被禁用，避免重复提交。

## 8. agent.Auth.login 如何发请求

`src/agent.js` 中：

```js
const API_ROOT = process.env.REACT_APP_BACKEND_URL ?? '/api';
```

开发环境里没有指定 `REACT_APP_BACKEND_URL` 时，默认请求：

```text
/api
```

登录 API：

```js
const Auth = {
  login: (email, password) =>
    requests.post('/users/login', { user: { email, password } }),
};
```

最终请求体是：

```js
{
  user: {
    email, password;
  }
}
```

底层统一走：

```js
const agent = async (url, body, method = 'GET') => {
  const headers = new Headers();

  if (body) {
    headers.set('Content-Type', 'application/json');
  }

  if (token) {
    headers.set('Authorization', `Token ${token}`);
  }

  const response = await fetch(`${API_ROOT}${url}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  if (!response.ok) throw result;

  return result;
};
```

所以登录请求是：

```text
POST /api/users/login
Content-Type: application/json

{"user":{"email":"...","password":"..."}}
```

## 9. ...user 是什么语法

登录成功后，接口返回大概是：

```js
{
  user: {
    email: 'a@test.com',
    username: 'chen',
    bio: null,
    image: null,
    token: 'jwt-token'
  }
}
```

代码中：

```js
const {
  user: { token, ...user },
} = await agent.Auth.login(email, password);
```

这里的 `...user` 是对象剩余属性语法。

意思是：

```js
const token = response.user.token;

const user = {
  email: response.user.email,
  username: response.user.username,
  bio: response.user.bio,
  image: response.user.image,
};
```

也就是：

```text
从 response.user 里单独取出 token
把剩下的字段收集成新的 user 对象
```

所以：

```js
return { token, user };
```

返回的是：

```js
{
  token: 'jwt-token',
  user: {
    email: 'a@test.com',
    username: 'chen',
    bio: null,
    image: null
  }
}
```

这个对象会成为 `auth/login/fulfilled` 的 `action.payload`。

## 10. fulfilled 阶段：写入 Redux state

登录成功后，`createAsyncThunk` 会 dispatch：

```text
auth/login/fulfilled
```

`authSlice.js` 中：

```js
builder
  .addCase(login.fulfilled, successReducer)
  .addCase(register.fulfilled, successReducer)
  .addCase(getUser.fulfilled, successReducer)
  .addCase(updateUser.fulfilled, successReducer);
```

命中 `login.fulfilled` 后执行：

```js
function successReducer(state, action) {
  state.status = Status.SUCCESS;
  state.token = action.payload.token;
  state.user = action.payload.user;
  delete state.errors;
}
```

所以 Redux state 变成：

```js
state.auth = {
  status: 'success',
  token: 'jwt-token',
  user: {
    email: 'a@test.com',
    username: 'chen',
  },
};
```

这一步才是真正修改 Redux 登录态的地方。

## 11. rejected 阶段：写入错误

如果后端返回错误，`agent` 会：

```js
if (!response.ok) throw result;
```

`login` 的 `catch` 中：

```js
if (isApiError(error)) {
  return thunkApi.rejectWithValue(error);
}
```

于是 `createAsyncThunk` dispatch：

```text
auth/login/rejected
```

`authSlice.js` 中：

```js
builder
  .addCase(login.rejected, failureReducer)
  .addCase(register.rejected, failureReducer)
  .addCase(updateUser.rejected, failureReducer);
```

`failureReducer`：

```js
export function failureReducer(state, action) {
  state.status = Status.FAILURE;
  state.errors = action.payload.errors;
}
```

然后 `AuthScreen`：

```js
const errors = useSelector(selectErrors);
```

渲染：

```jsx
<ListErrors errors={errors} />
```

所以失败流程是：

```text
请求失败
  -> auth/login/rejected
  -> state.auth.status = failure
  -> state.auth.errors = 后端错误
  -> AuthScreen 重新渲染
  -> ListErrors 展示错误
  -> then 里发现 requestStatus 是 rejected
  -> 不跳转
```

## 12. localStorageMiddleware 是什么

`src/app/middleware.js` 中：

```js
const localStorageMiddleware = (store) => (next) => (action) => {
  switch (action.type) {
    case register.fulfilled.type:
    case login.fulfilled.type:
      window.localStorage.setItem('jwt', action.payload.token);
      agent.setToken(action.payload.token);
      break;

    case logout.type:
      window.localStorage.removeItem('jwt');
      agent.setToken(undefined);
      break;
  }

  return next(action);
};
```

它是 Redux middleware。

它拦截的是：

```text
Redux action
```

不是 HTTP 请求。

所以它更像：

```text
Redux action interceptor
```

不是 OkHttp 的 HTTP interceptor。

和 OkHttp 类比：

```text
src/app/middleware.js
  -> 拦截 Redux action
  -> 适合做登录成功保存 token、登出清 token、日志、埋点、根据 action 做副作用

src/agent.js
  -> 封装 HTTP 请求
  -> 更像 OkHttp interceptor
  -> 适合统一加 header、token、请求参数、错误处理
```

## 13. middleware 在修改 state 前还是之后执行

当前这个 `localStorageMiddleware` 的副作用发生在 reducer 修改 state 之前。

关键是：

```js
return next(action);
```

`next(action)` 才会把 action 继续传下去。

如果后面没有其他 middleware，最终才会进入 Redux 原始 dispatch，然后 reducer 修改 state。

所以当前顺序是：

```text
dispatch(auth/login/fulfilled)
  -> localStorageMiddleware 收到 action
  -> window.localStorage.setItem('jwt', token)
  -> agent.setToken(token)
  -> next(action)
  -> authSlice successReducer 执行
  -> state.auth.token/state.auth.user 更新
```

如果想在 reducer 修改 state 之后做事，middleware 要这样写：

```js
const middleware = (store) => (next) => (action) => {
  // reducer 之前

  const result = next(action);

  // reducer 之后
  const state = store.getState();

  return result;
};
```

当前项目的写法是在 `next(action)` 之前保存 token。

## 14. localStorageMiddleware 如何接入 store

`src/app/store.js` 中：

```js
middleware: (getDefaultMiddleware) => [
  ...getDefaultMiddleware(),
  localStorageMiddleware,
],
```

`getDefaultMiddleware()` 里包含 thunk middleware。

然后项目又额外追加了：

```js
localStorageMiddleware;
```

所以完整 dispatch 链路可以理解为：

```text
dispatch(action)
  -> Redux Toolkit 默认 middleware
  -> localStorageMiddleware
  -> reducer
```

对于 `dispatch(login(...))` 这种 thunk：

```text
dispatch(login(...))
  -> thunk middleware 执行 login thunk
  -> thunk 内部 dispatch auth/login/pending
  -> thunk 内部请求 API
  -> thunk 内部 dispatch auth/login/fulfilled
  -> localStorageMiddleware 保存 token
  -> auth reducer 更新 state
```

## 15. 想给请求 header 或 request 增加参数，应该在哪里做

如果你想在请求前统一增加 header，不应该主要写在 `src/app/middleware.js`，而应该写在 `src/agent.js`。

因为 `middleware.js` 拦截的是 Redux action，不是 HTTP request。

统一加 header 的位置是：

```js
const agent = async (url, body, method = 'GET') => {
  const headers = new Headers();

  headers.set('X-App-Version', '1.0.0');
  headers.set('X-Platform', 'web');

  if (body) {
    headers.set('Content-Type', 'application/json');
  }

  if (token) {
    headers.set('Authorization', `Token ${token}`);
  }

  return fetch(...);
};
```

如果想给所有请求 body 增加字段，也可以在 `agent.js` 做，但要谨慎。

例如：

```js
body: body
  ? JSON.stringify({
      ...body,
      client: 'web',
    })
  : undefined;
```

这可能会破坏后端接口契约，因为并不是所有接口都允许多余字段。

更稳妥的做法是：

```text
通用 header：
  放在 agent.js 的 headers 中

某个接口专属参数：
  放在对应 API 方法中，例如 Auth.login、Articles.create

登录成功后保存 token：
  放在 Redux middleware 中
```

## 16. token 如何影响后续请求

`agent.js` 中有模块级变量：

```js
let token = null;
```

请求前：

```js
if (token) {
  headers.set('Authorization', `Token ${token}`);
}
```

登录成功后 middleware 执行：

```js
agent.setToken(action.payload.token);
```

`agent.setToken`：

```js
setToken: (_token) => {
  token = _token;
},
```

所以后续请求都会带：

```text
Authorization: Token jwt-token
```

注意，这里不是修改已经发出去的登录请求。

它是保存 token，让之后的请求带上认证头。

## 17. 登录成功后 Header 为什么变化

`src/components/Header.js` 中：

```js
const isAuthenticated = useSelector(selectIsAuthenticated);
```

`selectIsAuthenticated`：

```js
export const selectIsAuthenticated = createSelector(
  (state) => selectAuthSlice(state).token,
  selectUser,
  (token, user) => Boolean(token && user)
);
```

登录成功后：

```text
state.auth.token 有值
state.auth.user 有值
  -> selectIsAuthenticated 返回 true
```

Header 渲染：

```jsx
{
  isAuthenticated ? <LoggedInNavbar /> : <LoggedOutNavbar />;
}
```

所以顶部导航从：

```text
Home / Sign in / Sign up
```

变成：

```text
Home / New Post / Settings / username
```

这是 Redux state 改变后，React-Redux 通过 `useSelector` 通知组件重新渲染的结果。

## 18. 登录成功后为什么跳转

`AuthScreen.js` 中：

```js
dispatch(login({ email, password })).then((action) => {
  if (action.meta.requestStatus === 'rejected') {
    return;
  }

  navigate('/');
});
```

`dispatch(login(...))` 返回的 Promise 会在 `fulfilled/rejected action` 已经 dispatch 完之后 resolve。

成功时：

```js
action.meta.requestStatus === 'fulfilled';
```

所以执行：

```js
navigate('/');
```

失败时：

```js
action.meta.requestStatus === 'rejected';
```

所以直接 `return`，不跳转。

## 19. 当前代码里的 catch

如果写：

```js
dispatch(login({ email, password }))
  .then((action) => {
    if (action.meta.requestStatus === 'rejected') {
      return;
    }
    navigate('/');
  })
  .catch((error) => {});
```

语法是正确的。

但 `createAsyncThunk` 默认失败时不会进入这个 `catch`。

它会 resolve 一个 rejected action：

```text
auth/login/rejected
```

所以失败主要在 `.then` 里通过下面判断处理：

```js
action.meta.requestStatus === 'rejected';
```

如果希望失败进入 `catch`，要使用：

```js
dispatch(login({ email, password }))
  .unwrap()
  .then((payload) => {
    navigate('/');
  })
  .catch((error) => {
    // rejected 时进入这里
  });
```

## 20. 刷新页面后如何恢复登录态

`src/components/App.js` 中：

```js
useEffect(() => {
  const token = window.localStorage.getItem('jwt');
  dispatch(appLoad(token));
}, []);
```

应用首次加载时：

```text
从 localStorage 读取 jwt
  -> dispatch(appLoad(token))
```

`src/reducers/common.js` 中：

```js
export const appLoad = (token) => (dispatch) => {
  dispatch(commonSlice.actions.loadApp());

  if (token) {
    agent.setToken(token);
    dispatch(setToken(token));
    return dispatch(getUser());
  }
};
```

有 token 时：

```text
agent.setToken(token)
  -> 后续请求带 Authorization

dispatch(setToken(token))
  -> state.auth.token 先恢复

dispatch(getUser())
  -> 请求 /user
  -> 成功后恢复 state.auth.user
```

所以刷新后还能保持登录态。

## 21. 登录流程总图

完整登录成功流程：

```text
访问 /login
  -> React Router 渲染 AuthScreen
  -> 用户输入 email/password
  -> useState 保存输入
  -> 提交 form
  -> event.preventDefault()
  -> dispatch(login({ email, password }))
  -> thunk middleware 执行 login thunk
  -> auth/login/pending
  -> auth.status = loading
  -> 表单 disabled
  -> agent.Auth.login 发 POST /users/login
  -> 后端返回 user + token
  -> 解构出 token 和 user
  -> auth/login/fulfilled
  -> localStorageMiddleware 保存 jwt
  -> agent.setToken(token)
  -> successReducer 写入 state.auth.token/state.auth.user
  -> Header 重新渲染为登录状态
  -> then 拿到 fulfilled action
  -> navigate('/')
```

完整登录失败流程：

```text
访问 /login
  -> 用户输入错误 email/password
  -> dispatch(login({ email, password }))
  -> auth/login/pending
  -> agent.Auth.login 请求失败
  -> agent throw result
  -> thunkApi.rejectWithValue(error)
  -> auth/login/rejected
  -> failureReducer 写入 state.auth.errors
  -> AuthScreen 重新渲染
  -> ListErrors 展示错误
  -> then 拿到 rejected action
  -> 不跳转
```

职责分工：

```text
AuthScreen：
  收集输入、提交登录、根据结果跳转

authSlice：
  定义 login/register/getUser/updateUser
  处理 pending/fulfilled/rejected
  保存 token/user/errors/status

agent：
  统一封装 HTTP 请求
  设置 Content-Type、Authorization
  抛出接口错误

localStorageMiddleware：
  监听 login/register fulfilled
  保存 jwt
  设置 agent token
  监听 logout 清理 jwt

Header：
  根据 selectIsAuthenticated 渲染登录/未登录导航

App：
  首次加载读取 localStorage jwt
  dispatch(appLoad(token)) 恢复登录态
```
