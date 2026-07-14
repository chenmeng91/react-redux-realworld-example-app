# 07. API 请求封装和 Redux 异步流程

这一部分对应 `LEARNING.md` 里的“API 请求封装”，同时融合了关于开发代理、CORS、部署、`createAsyncThunk`、middleware、`createSlice`、reducer/action 的追问。

主要参考文件：

- `src/agent.js`
- `src/setupProxy.js`
- `src/features/auth/authSlice.js`
- `src/app/store.js`
- `src/app/middleware.js`
- `src/features/auth/AuthScreen.js`

## 1. 为什么要封装 API 请求

这个项目没有在每个组件里直接写 `fetch`。

而是统一封装了：

```text
src/agent.js
```

原因是请求里有很多共性逻辑：

- API 根地址
- GET / POST / PUT / DELETE
- JSON 序列化
- token 请求头
- 错误处理
- 分页参数转换
- 业务接口分组

如果每个组件都直接写 `fetch`，会造成：

```text
重复代码多
URL 分散
token 处理分散
错误处理不统一
以后换 API 地址麻烦
测试更难
```

封装后，上层可以写更有业务语义的代码：

```js
agent.Auth.login(email, password);
agent.Articles.get(slug);
agent.Comments.create(slug, comment);
```

## 2. `API_ROOT`

`src/agent.js` 开头：

```js
const API_ROOT = process.env.REACT_APP_BACKEND_URL ?? '/api';
```

含义：

```text
如果设置了 REACT_APP_BACKEND_URL，就用环境变量里的后端地址
否则默认请求 /api
```

当前开发环境使用：

```text
/api
```

也就是说前端请求：

```text
http://localhost:4100/api/users/login
```

而不是直接请求：

```text
https://conduit-api.bondaracademy.com/api/users/login
```

这样做是为了开发环境绕开浏览器 CORS 限制。

## 3. `setupProxy.js` 开发代理

`src/setupProxy.js`：

```js
const { createProxyMiddleware } = require('http-proxy-middleware');

module.exports = function setupProxy(app) {
  app.use(
    '/api',
    createProxyMiddleware({
      target: 'https://conduit-api.bondaracademy.com',
      changeOrigin: true,
      onProxyReq(proxyReq) {
        proxyReq.removeHeader('origin');
      },
    })
  );
};
```

这段代码的作用：

```text
所有发到本地 /api 开头的请求
都由 CRA dev server 转发到 https://conduit-api.bondaracademy.com
```

例如：

```text
浏览器请求：
http://localhost:4100/api/users/login

开发服务器转发到：
https://conduit-api.bondaracademy.com/api/users/login
```

### `http-proxy-middleware` 是什么

`http-proxy-middleware` 是 Node / Express 风格开发服务器中常用的代理中间件。

Create React App 的开发服务器可以加载 `src/setupProxy.js`，并把内部的 `app` 传给这个函数。

所以可以通过：

```js
app.use('/api', createProxyMiddleware(...))
```

注册代理规则。

### 为什么 target 不带 `/api`

配置是：

```js
target: 'https://conduit-api.bondaracademy.com';
```

而不是：

```js
target: 'https://conduit-api.bondaracademy.com/api';
```

因为本地请求路径本身已经包含 `/api`。

最终拼接是：

```text
target + 原始路径
= https://conduit-api.bondaracademy.com + /api/users/login
= https://conduit-api.bondaracademy.com/api/users/login
```

### `changeOrigin: true`

```js
changeOrigin: true;
```

会把代理请求中的 `Host` 改成目标服务器的 host。

也就是让远端 API 看到请求像是发给：

```text
conduit-api.bondaracademy.com
```

而不是：

```text
localhost:4100
```

### `removeHeader('origin')`

```js
onProxyReq(proxyReq) {
  proxyReq.removeHeader('origin');
}
```

我们加这个是因为远端 API 会检查 `Origin`。

如果带着：

```text
Origin: http://localhost:4100
```

远端可能返回：

```text
"Not allowed by CORS"
```

删除 `Origin` 后，它更像普通服务端请求。

## 4. `setupProxy.js` 什么时候被加载

`src/setupProxy.js` 是 Create React App 的约定文件。

执行：

```bash
npm start
```

时，`react-scripts start` 会启动 CRA dev server，并自动检查：

```text
src/setupProxy.js
```

如果存在，就加载它并调用：

```js
module.exports = function setupProxy(app) {};
```

加载流程：

```text
npm start
  -> react-scripts start
  -> 创建开发服务器
  -> 加载 src/setupProxy.js
  -> 调用 setupProxy(app)
  -> 注册 /api 代理中间件
  -> dev server 开始监听端口
```

注意：

```text
setupProxy.js 运行在 Node.js 开发服务器里
不是运行在浏览器里
```

所以它使用 CommonJS：

```js
require(...)
module.exports = ...
```

如果修改了 `setupProxy.js`，通常需要重启开发服务器。

## 5. `setupProxy.js` 文件名是否固定

在 Create React App 中，如果想让 CRA 自动加载代理配置，文件名和位置必须是：

```text
src/setupProxy.js
```

如果改成：

```text
src/proxy.js
src/setup-proxy.js
config/setupProxy.js
```

CRA 默认不会自动识别。

## 6. CORS 是什么

CORS 全称是 Cross-Origin Resource Sharing，中文通常叫跨源资源共享。

它是浏览器的安全机制，用来限制网页随便请求其他源的资源。

“源”由三部分组成：

```text
协议 + 域名 + 端口
```

例如：

```text
http://localhost:4100
```

如果页面在：

```text
http://localhost:4100
```

请求：

```text
https://conduit-api.bondaracademy.com/api
```

这就是跨源。

浏览器会要求远端 API 明确允许这个来源。

例如响应头：

```http
Access-Control-Allow-Origin: http://localhost:4100
```

如果远端 API 不允许，浏览器就会拦截响应。

这里要区分：

```text
真正做允许/拒绝判断的是远端 API
真正执行拦截的是浏览器
```

本项目中，不允许的是：

```text
https://conduit-api.bondaracademy.com/api
```

不是本地 `localhost:4100`。

## 7. 预检请求 OPTIONS

某些跨域请求在真正发送前，浏览器会先发：

```http
OPTIONS /api/users/login
```

这个叫预检请求。

浏览器是在问服务器：

```text
我这个 Origin 能不能发 POST？
我能不能带 Content-Type？
我能不能带 Authorization？
```

如果服务器不允许，真正的 POST 请求不会继续发，浏览器会报 CORS error。

`curl` 不受 CORS 限制，因为 CORS 是浏览器策略。

所以可能出现：

```text
curl 请求成功
浏览器请求失败
```

## 8. React 开发时是否必须启动开发服务器

React 本身不强制必须启动开发服务器。

但现代 React 工程通常需要开发服务器，因为它负责：

- 编译 JSX
- 打包模块
- 处理 import
- 热更新
- 代理 API
- 前端路由 fallback
- 注入环境变量
- 显示编译错误

当前项目是 Create React App，开发时通常运行：

```bash
npm start
```

对这个项目来说，开发时基本需要 dev server。

## 9. 部署时是否需要 Node 服务器

React SPA 构建后通常不需要 Node 服务器。

执行：

```bash
npm run build
```

会生成静态文件：

```text
build/index.html
build/static/js/...
build/static/css/...
```

可以部署到：

- Nginx
- Apache
- CDN
- 对象存储
- Netlify / Vercel 静态托管
- GitHub Pages

但要注意两点。

### 前端路由 fallback

因为项目使用 `BrowserRouter`。

用户直接访问：

```text
/register
/article/xxx
/settings
```

静态服务器需要返回：

```text
index.html
```

让 React Router 接管。

Nginx 示例：

```nginx
location / {
  try_files $uri /index.html;
}
```

### 生产环境 API 代理

`src/setupProxy.js` 只在 `npm start` 开发环境生效。

生产部署时不会生效。

如果前端继续请求：

```text
/api
```

生产环境需要配置：

```text
/api -> 后端服务
```

例如 Nginx：

```nginx
location /api/ {
  proxy_pass https://conduit-api.bondaracademy.com/api/;
}
```

也可以构建时指定真实后端地址：

```bash
REACT_APP_BACKEND_URL=https://your-api.example.com/api npm run build
```

但直接请求真实后端仍然可能遇到 CORS，前提是后端必须允许你的前端域名。

## 10. `requests` 是什么

`src/agent.js` 中：

```js
const requests = {
  del: (url) => agent(url, undefined, 'DELETE'),
  get: (url, query = {}) => { ... },
  put: (url, body) => agent(url, body, 'PUT'),
  post: (url, body) => agent(url, body, 'POST'),
};
```

`requests` 是一个普通 JavaScript 对象。

它里面放了 4 个函数：

```js
requests.del;
requests.get;
requests.put;
requests.post;
```

作用是把常用 HTTP 方法封装起来。

例如：

```js
requests.post('/users/login', { user: { email, password } });
```

最终会调用：

```js
agent('/users/login', { user: { email, password } }, 'POST');
```

## 11. 底层 `agent` 请求函数

`src/agent.js` 中：

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

  let result;

  try {
    result = await response.json();
  } catch (error) {
    result = { errors: { [response.status]: [response.statusText] } };
  }

  if (!response.ok) throw result;

  return result;
};
```

这个函数统一处理：

- 请求 URL
- 请求方法
- JSON body
- `Content-Type`
- `Authorization`
- JSON 响应解析
- 错误抛出

如果响应不是 2xx：

```js
if (!response.ok) throw result;
```

上层 async thunk 会捕获这个错误。

## 12. 业务接口分组

`agent.js` 中按业务资源分组：

```js
const Auth = {
  current: () => requests.get('/user'),
  login: (email, password) =>
    requests.post('/users/login', { user: { email, password } }),
  register: (username, email, password) =>
    requests.post('/users', { user: { username, email, password } }),
  save: (user) => requests.put('/user', { user }),
};
```

文章：

```js
agent.Articles.get(slug);
agent.Articles.create(article);
agent.Articles.update(article);
agent.Articles.favorite(slug);
```

评论：

```js
agent.Comments.forArticle(slug);
agent.Comments.create(slug, comment);
agent.Comments.delete(slug, commentId);
```

用户资料：

```js
agent.Profile.get(username);
agent.Profile.follow(username);
agent.Profile.unfollow(username);
```

标签：

```js
agent.Tags.getAll();
```

## 13. `createAsyncThunk` 创建了什么

在 `authSlice.js` 中：

```js
export const login = createAsyncThunk(
  'auth/login',
  async ({ email, password }, thunkApi) => {
    ...
  }
);
```

`createAsyncThunk` 创建的是一个异步 action creator。

`login` 是一个函数。

调用：

```js
login({ email, password });
```

会返回一个 thunk action，可以被 `dispatch` 执行。

`createAsyncThunk` 会根据第一个参数：

```js
'auth/login';
```

自动生成三种 action type：

```text
auth/login/pending
auth/login/fulfilled
auth/login/rejected
```

对应：

```js
login.pending.type;
login.fulfilled.type;
login.rejected.type;
```

所以 `login` 是一个带附加属性的函数：

```text
login(...)
login.pending
login.fulfilled
login.rejected
```

## 14. `dispatch(login(...))` 完整流程

`AuthScreen.js` 中：

```js
dispatch(login({ email, password }));
```

流程：

```text
dispatch(login({ email, password }))
  -> thunk middleware 发现 dispatch 的是函数
  -> 执行这个 thunk
  -> createAsyncThunk 自动 dispatch auth/login/pending
  -> 执行 async 函数
  -> async 函数调用 agent.Auth.login(email, password)
  -> 请求成功：dispatch auth/login/fulfilled
  -> 请求失败：dispatch auth/login/rejected
```

`createAsyncThunk` 如何判断成功失败：

```text
async 函数正常 return
  -> fulfilled

async 函数 throw error
或 return thunkApi.rejectWithValue(error)
  -> rejected
```

Redux 本身不知道登录是否成功。

是 `createAsyncThunk` 根据你传进去的 async 函数执行结果判断。

## 15. agent 如何被 Redux 调用

登录 thunk 中：

```js
const {
  user: { token, ...user },
} = await agent.Auth.login(email, password);

return { token, user };
```

调用链：

```text
AuthScreen
  -> dispatch(login({ email, password }))
  -> login thunk
  -> agent.Auth.login(email, password)
  -> requests.post('/users/login', { user: { email, password } })
  -> agent('/users/login', body, 'POST')
  -> fetch('/api/users/login')
```

组件不直接关心 URL、headers、JSON 解析和错误处理。

## 16. 真正修改 state 的位置

登录请求成功后，`createAsyncThunk` 会 dispatch：

```text
auth/login/fulfilled
```

真正修改 `state.auth` 的地方是 `successReducer`：

```js
function successReducer(state, action) {
  state.status = Status.SUCCESS;
  state.token = action.payload.token;
  state.user = action.payload.user;
  delete state.errors;
}
```

它通过 `extraReducers` 绑定：

```js
extraReducers(builder) {
  builder
    .addCase(login.fulfilled, successReducer)
    .addCase(register.fulfilled, successReducer)
    .addCase(getUser.fulfilled, successReducer)
    .addCase(updateUser.fulfilled, successReducer);
}
```

关键是：

```js
.addCase(login.fulfilled, successReducer)
```

意思是：

```text
当 action.type 是 auth/login/fulfilled 时
调用 successReducer
```

Redux Toolkit 使用 Immer，所以可以写：

```js
state.token = action.payload.token;
```

看起来像直接修改 state，实际会生成新的 immutable state。

## 17. 页面为什么重新渲染

`Header.js` 中：

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
```

所以：

```js
selectIsAuthenticated(state);
```

从 `false` 变成 `true`。

React-Redux 的 `useSelector` 发现选中的值变了，于是通知 React 重新渲染 `Header`。

`Header` 中：

```jsx
{
  isAuthenticated ? <LoggedInNavbar /> : <LoggedOutNavbar />;
}
```

会从未登录导航切换成登录导航。

## 18. middleware 在哪里设置

`src/app/store.js` 中：

```js
middleware: (getDefaultMiddleware) => [
  ...getDefaultMiddleware(),
  localStorageMiddleware,
],
```

这里把项目自己的 `localStorageMiddleware` 加入 Redux middleware 链。

middleware 可以理解为：

```text
所有 dispatch(action) 都会先经过 middleware，再到 reducer
```

## 19. localStorageMiddleware 为什么登录成功会执行

`src/app/middleware.js`：

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

登录成功后会出现 action：

```js
{
  type: 'auth/login/fulfilled',
  payload: {
    token,
    user
  }
}
```

这个 action 会经过 middleware。

middleware 匹配到：

```js
case login.fulfilled.type:
```

于是执行：

```js
window.localStorage.setItem('jwt', action.payload.token);
agent.setToken(action.payload.token);
```

然后：

```js
return next(action);
```

把 action 继续交给后面的 middleware 和 reducer。

如果不调用 `next(action)`，reducer 就收不到这个 action。

## 20. token 如何进入 agent

`agent.js` 中有模块变量：

```js
let token = null;
```

导出：

```js
setToken: (_token) => {
  token = _token;
};
```

登录成功后：

```text
localStorageMiddleware
  -> agent.setToken(action.payload.token)
```

之后所有经过 `agent()` 的请求都会自动带：

```http
Authorization: Token xxx
```

刷新页面时，`App` 会读取：

```js
const token = window.localStorage.getItem('jwt');
dispatch(appLoad(token));
```

`appLoad` 中：

```js
if (token) {
  agent.setToken(token);
  dispatch(setToken(token));
  return dispatch(getUser());
}
```

所以刷新后也能恢复登录态。

## 21. `authSlice`、reducer、action 的关系

`authSlice` 是：

```js
const authSlice = createSlice(...)
```

创建出来的 Redux Toolkit slice 对象。

它本身不是 reducer，也不是 action。

它是一个包含这些内容的对象：

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

### action

action 是一个普通对象，用来描述发生了什么。

例如：

```js
{
  type: 'auth/setToken',
  payload: 'jwt.token.here'
}
```

它本身不修改 state。

### reducer

reducer 是函数，用来根据 action 更新 state。

基本模型：

```text
旧 state + action -> 新 state
```

例如：

```js
setToken(state, action) {
  state.token = action.payload;
}
```

### `createSlice` 生成 actions 和 reducer

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

`reducers` 中的 `setToken` 会生成：

```js
authSlice.actions.setToken(token);
```

这个 action creator 会生成 action：

```js
{
  type: 'auth/setToken',
  payload: token
}
```

`authSlice.reducer` 负责处理这些 action。

## 22. 为什么 `export default authSlice.reducer` 后可以 `import authReducer`

`authSlice.js` 中：

```js
export default authSlice.reducer;
```

表示这个模块默认导出的是：

```js
authSlice.reducer;
```

`store.js` 中：

```js
import authReducer from '../features/auth/authSlice';
```

这里的 `authReducer` 是导入方自己起的名字。

因为默认导入可以自由命名。

所以：

```js
authReducer === authSlice.reducer;
```

之所以命名为 `authReducer`，是为了表达用途：

```text
这是 auth 模块的 reducer
```

然后挂到：

```js
reducer: {
  auth: authReducer,
}
```

表示：

```text
state.auth 由 authReducer 管理
```

## 23. 完整登录链路

```text
用户输入 email/password
  -> 点击 Sign in
  -> form onSubmit 触发 authenticateUser
  -> dispatch(login({ email, password }))

createAsyncThunk
  -> dispatch auth/login/pending
  -> 执行 async 函数
  -> 调用 agent.Auth.login(email, password)

agent
  -> requests.post('/users/login', body)
  -> agent('/users/login', body, 'POST')
  -> fetch('/api/users/login')
  -> 后端返回 token/user

createAsyncThunk
  -> async 函数 return { token, user }
  -> dispatch auth/login/fulfilled

middleware
  -> localStorageMiddleware 匹配 login.fulfilled
  -> localStorage 保存 jwt
  -> agent.setToken(token)
  -> next(action)

authReducer
  -> extraReducers 匹配 login.fulfilled
  -> successReducer 修改 state.auth.token/user

React-Redux
  -> Header 的 useSelector(selectIsAuthenticated) 发现结果变化
  -> Header 重新渲染
  -> 显示 LoggedInNavbar

AuthScreen
  -> dispatch(login(...)).then(...)
  -> fulfilled 后 navigate('/')
```

## 24. 本节重点

```text
1. agent.js 是 API client，封装 fetch、headers、token、错误处理和业务接口。
2. setupProxy.js 是开发服务器代理，只在 npm start 时生效。
3. CORS 是浏览器安全策略，不是 curl 或服务端请求限制。
4. requests 是普通对象，封装 get/post/put/delete。
5. createAsyncThunk 创建异步 action creator。
6. login 是函数，调用 login(...) 返回 thunk action。
7. createAsyncThunk 自动发 pending/fulfilled/rejected。
8. fulfilled action 被 extraReducers 捕获后，successReducer 修改 state.auth。
9. middleware 监听 action，可以做保存 token 这类副作用。
10. authSlice 是 slice 对象，里面包含 reducer 和 actions。
```

完整心智模型：

```text
组件不直接关心 fetch
组件 dispatch thunk
thunk 调用 agent
agent 调用后端
结果回到 thunk
thunk dispatch fulfilled/rejected
middleware 做副作用
reducer 改 state
useSelector 触发页面更新
```
