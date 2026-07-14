# 02. 启动流程、项目配置和状态管理基础

这一部分围绕项目启动流程展开，同时记录后续追问中涉及的 `package.json`、`store.js`、reducer、Redux 和 React `useReducer`。

## 1. 项目启动流程

这个项目启动时的主线是：

```text
package.json
  -> npm start
  -> public/index.html
  -> src/index.js
  -> src/app/store.js
  -> src/components/App.js
```

`package.json` 里的启动脚本是：

```json
"start": "cross-env PORT=4100 react-scripts start"
```

含义：

- `PORT=4100`：指定本地开发服务器端口。
- `react-scripts start`：启动 Create React App 开发服务器。
- CRA 会编译 `src` 下的 React 代码，并把结果挂载到 HTML 页面中。

## 2. `public/index.html` 和 `src/index.js`

`public/index.html` 里有：

```html
<div id="root"></div>
```

这个 `root` 是 React 应用的挂载点。

`src/index.js` 里通过下面的代码找到这个节点：

```js
createRoot(document.getElementById('root')).render(...)
```

可以理解为：

```text
HTML 提供容器
React 把组件树渲染进这个容器
```

核心组件树是：

```jsx
<Provider store={store}>
  <Router>
    <App />
  </Router>
</Provider>
```

含义：

- `Provider`：把 Redux store 提供给整个 React 应用。
- `Router`：让应用支持前端路由。
- `App`：应用根组件，负责组织页面。

## 3. `package.json` 是什么

`package.json` 不是 React 独有的文件，而是 Node.js / JavaScript 生态的项目配置标准。

React、Vue、Angular、Next.js、Node 后端项目通常都会有它。

它主要放：

- 项目基本信息：`name`、`version`、`private`
- 运行脚本：`start`、`build`、`test`
- 生产依赖：`dependencies`
- 开发依赖：`devDependencies`
- 浏览器兼容配置：`browserslist`

所以可以理解为：

```text
package.json
  = 项目信息
  + npm 命令
  + 依赖库
  + 构建/测试/兼容配置
```

它是前端工程和 Node 生态的标准文件，不是 React 的专属写法。

## 4. `store.js` 做了什么

`src/app/store.js` 用来创建 Redux 全局 store。

核心代码：

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

`configureStore` 是 Redux Toolkit 提供的创建 store 的方法。

这段代码做了几件事：

- 声明全局状态分成哪些模块。
- 指定每个模块由哪个 reducer 管理。
- 开启 Redux DevTools。
- 支持传入初始状态 `preloadedState`。
- 加入默认 middleware 和项目自定义的 `localStorageMiddleware`。

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

例如：

```js
auth: authReducer;
```

表示：

```text
state.auth 这块状态由 authReducer 管理
```

## 5. `articleReducer`、`authReducer` 这些值怎么来的

它们不是在 `store.js` 里生成的，而是从其他模块导入的：

```js
import authReducer from '../features/auth/authSlice';
import articlesReducer from '../reducers/articleList';
```

以 `authReducer` 为例。

`src/features/auth/authSlice.js` 里有：

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

`createSlice` 会生成：

```js
authSlice.reducer;
authSlice.actions;
```

文件最后导出：

```js
export default authSlice.reducer;
```

所以 `store.js` 里的：

```js
import authReducer from '../features/auth/authSlice';
```

拿到的就是：

```js
authSlice.reducer;
```

完整链路：

```text
createSlice(...)
  -> 生成 authSlice
  -> authSlice.reducer
  -> export default
  -> store.js import 成 authReducer
  -> 挂到 state.auth
```

## 6. reducer 函数是什么意思

reducer 是一个负责“根据 action 更新 state”的函数。

基本形状：

```js
function reducer(state, action) {
  return newState;
}
```

它接收：

- `state`：当前状态
- `action`：发生了什么事情

它返回：

- 新的 `state`

可以简化理解为：

```text
旧 state + action -> 新 state
```

例如：

```js
function counterReducer(state, action) {
  if (action.type === 'increment') {
    return {
      count: state.count + 1,
    };
  }

  return state;
}
```

在本项目里，`authReducer` 管理的是 `state.auth`。

登录成功时，会触发类似这样的 action：

```js
{
  type: 'auth/login/fulfilled',
  payload: {
    token: '...',
    user: {...}
  }
}
```

`authReducer` 收到这个 action 后，把 `token` 和 `user` 存进 `state.auth`。

## 7. Redux 和 reducer 的关系

Redux 不是“原生 reducer 的升级版”。

更准确地说：

```text
reducer 是一种状态计算函数
Redux 是围绕 reducer 建立的一套状态管理方案
```

Redux 不只是 reducer，它还包括：

- `store`：保存全局状态。
- `dispatch`：发送 action。
- `action`：描述发生了什么。
- `middleware`：扩展 dispatch 流程，例如异步、本地存储、日志。
- React 绑定：`Provider`、`useSelector`、`useDispatch`。

所以可以这样记：

```text
Reducer：怎么算新状态
Redux：状态放哪、怎么改、谁能读、谁来通知页面更新
```

## 8. Redux reducer 和 React `useReducer`

React 原生也有 `useReducer`：

```js
const [state, dispatch] = useReducer(reducer, initialState);
```

它和 Redux reducer 的思想一样：

```text
旧 state + action -> 新 state
```

区别在于作用范围。

`useReducer` 更适合组件内部，或者一小片组件树内部的复杂状态。

Redux 更适合全应用共享状态。

例如登录态不只登录页要用：

- `Header` 要根据是否登录显示不同导航。
- 文章页面要判断是否能编辑或删除。
- 请求接口时要带 token。
- 设置页要显示当前用户信息。

所以登录态放到 Redux 全局 store 里更合适。

可以这样理解：

```text
useReducer：组件级状态管理
Redux：应用级状态管理
```

它们不是谁替代谁，而是使用场景不同。

## 9. 当前阶段先记住的关系

```text
store.js 负责组装全局 store
authSlice.js 负责生成 authReducer 和 auth actions
authReducer 负责管理 state.auth
组件通过 useSelector 读取 state
组件通过 useDispatch 触发 action
```

后面讲登录流程时，这条链路会完整串起来：

```text
用户点 Sign in
  -> AuthScreen dispatch(login(...))
  -> login 是 createAsyncThunk 创建的异步 action
  -> 请求 API
  -> 成功后触发 login.fulfilled
  -> authReducer 更新 state.auth
  -> Header 重新渲染成登录态
```
