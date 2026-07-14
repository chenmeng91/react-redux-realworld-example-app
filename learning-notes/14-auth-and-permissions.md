# 14. 权限和用户态

这一部分对应 `LEARNING.md` 里的“权限和用户态”，主要总结当前用户、登录态、token 持久化、页面/组件/thunk 权限控制，以及 `createSelector` 的作用。

主要参考文件：

- `src/features/auth/authSlice.js`
- `src/components/Header.js`
- `src/components/App.js`
- `src/reducers/common.js`
- `src/app/middleware.js`
- `src/features/auth/SettingsScreen.js`
- `src/features/comments/commentsSlice.js`
- `src/components/Article/ArticleMeta.js`
- `src/components/Home/index.js`

## 1. 用户态解决什么问题

用户态主要回答三个问题：

```text
当前用户是谁？
当前是否已登录？
当前用户能不能做某个操作？
```

在这个项目里，用户态主要保存在 Redux 的 `auth` slice 中。

登录成功后大概是：

```js
state.auth = {
  status: 'success',
  token: 'jwt-token',
  user: {
    email: 'a@test.com',
    username: 'chen',
    bio: null,
    image: null,
  },
};
```

核心字段：

```text
token：
  登录凭证，用来请求需要权限的接口

user：
  当前登录用户信息

status：
  当前认证相关请求状态

errors：
  登录、注册、更新用户失败时的错误
```

## 2. 登录成功后 token/user 如何进入 Redux

`authSlice.js` 中：

```js
export const login = createAsyncThunk(
  'auth/login',
  async ({ email, password }, thunkApi) => {
    const {
      user: { token, ...user },
    } = await agent.Auth.login(email, password);

    return { token, user };
  }
);
```

登录成功后返回：

```js
{
  token, user;
}
```

然后命中：

```js
.addCase(login.fulfilled, successReducer)
```

`successReducer`：

```js
function successReducer(state, action) {
  state.status = Status.SUCCESS;
  state.token = action.payload.token;
  state.user = action.payload.user;
  delete state.errors;
}
```

所以登录成功后：

```js
state.auth.token = action.payload.token;
state.auth.user = action.payload.user;
```

注册成功、刷新后获取当前用户、更新用户成功，也都复用这个 reducer：

```js
.addCase(login.fulfilled, successReducer)
.addCase(register.fulfilled, successReducer)
.addCase(getUser.fulfilled, successReducer)
.addCase(updateUser.fulfilled, successReducer)
```

## 3. selectUser：读取当前用户

`authSlice.js` 中：

```js
const selectAuthSlice = (state) => state.auth;
```

然后：

```js
export const selectUser = (state) => selectAuthSlice(state).user;
```

所以：

```js
useSelector(selectUser);
```

等价于：

```js
useSelector((state) => state.auth.user);
```

它读取的是当前登录用户。

## 4. createSelector 是什么

`createSelector` 是用来创建 selector 的工具函数，来自 Reselect，Redux Toolkit 默认导出它。

作用：

```text
从 Redux state 中取一些数据
经过计算得到一个结果
并且带缓存，避免没必要的重复计算
```

通用格式：

```js
const selector = createSelector(inputSelector1, inputSelector2, resultFunction);
```

执行逻辑：

```text
inputSelector1(state) -> value1
inputSelector2(state) -> value2
resultFunction(value1, value2) -> finalResult
```

例如：

```js
const selectFullName = createSelector(
  (state) => state.user.firstName,
  (state) => state.user.lastName,
  (firstName, lastName) => `${firstName} ${lastName}`
);
```

`createSelector` 返回的仍然是一个函数，可以传给 `useSelector`：

```js
const fullName = useSelector(selectFullName);
```

如果输入值没有变化，它会复用上一次计算结果。

## 5. selectIsAuthenticated：判断是否登录

`authSlice.js` 中：

```js
export const selectIsAuthenticated = createSelector(
  (state) => selectAuthSlice(state).token,
  selectUser,
  (token, user) => Boolean(token && user)
);
```

这里有两个输入 selector：

```js
(state) => selectAuthSlice(state).token;
```

读取：

```js
state.auth.token;
```

`selectUser` 读取：

```js
state.auth.user;
```

最后一个函数是结果计算函数：

```js
(token, user) => Boolean(token && user);
```

所以：

```text
token 和 user 都存在
  -> 已登录

token 不存在
  -> 未登录

user 还没加载出来
  -> 暂时也认为未登录
```

普通写法也可以：

```js
export const selectIsAuthenticated = (state) => {
  const token = state.auth.token;
  const user = state.auth.user;

  return Boolean(token && user);
};
```

项目里用 `createSelector` 是为了表达：

```text
isAuthenticated 是从 token 和 user 派生出来的状态
```

## 6. Header 如何根据登录态变化

`Header.js` 中：

```js
function Header() {
  const isAuthenticated = useSelector(selectIsAuthenticated);
  const appName = useSelector((state) => state.common.appName);

  return (
    <nav className="navbar navbar-light">
      <div className="container">
        <Link to="/" className="navbar-brand">
          {appName.toLowerCase()}
        </Link>

        {isAuthenticated ? <LoggedInNavbar /> : <LoggedOutNavbar />}
      </div>
    </nav>
  );
}
```

未登录显示：

```text
Home
Sign in
Sign up
```

已登录显示：

```text
Home
New Post
Settings
当前用户名
```

`LoggedInNavbar` 中：

```js
const currentUser = useSelector(selectUser);
```

用当前用户显示头像和用户名：

```jsx
<Link to={`/@${currentUser?.username}`} className="nav-link">
  <img src={currentUser?.image || 默认头像} />
  {currentUser?.username}
</Link>
```

登录成功后：

```text
state.auth.token/user 更新
  -> selectIsAuthenticated 结果变 true
  -> Header 重新渲染
  -> 显示 LoggedInNavbar
```

## 7. token 如何保存到 localStorage

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

登录或注册成功时：

```text
localStorage 保存 jwt
agent.setToken(token)
```

`localStorage` 用于刷新后恢复登录态。

`agent.setToken(token)` 用于让后续请求自动带：

```text
Authorization: Token xxx
```

登出时：

```text
删除 localStorage.jwt
清空 agent token
```

## 8. 刷新页面后如何恢复用户态

`App.js` 中：

```js
useEffect(() => {
  const token = window.localStorage.getItem('jwt');
  dispatch(appLoad(token));
}, []);
```

应用启动时：

```text
读取 localStorage.jwt
dispatch(appLoad(token))
```

`common.js` 中：

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
  -> 先恢复 state.auth.token

dispatch(getUser())
  -> GET /user
  -> 成功后恢复 state.auth.user
```

完整恢复流程：

```text
localStorage.jwt
  -> state.auth.token
  -> GET /user
  -> state.auth.user
  -> selectIsAuthenticated 返回 true
```

## 9. appLoaded 的作用和不足

`App.js` 中：

```js
const appLoaded = useSelector((state) => state.common.appLoaded);
```

未加载时：

```jsx
<>
  <Header />
  <p>Loading...</p>
</>
```

`appLoad` 一开始执行：

```js
dispatch(commonSlice.actions.loadApp());
```

对应 reducer：

```js
loadApp(state) {
  state.appLoaded = true;
}
```

所以 `appLoaded` 用来控制是否显示主路由。

但这个 demo 里实现比较粗糙：它在 `getUser()` 完成前就把 `appLoaded` 设为 true。

因此刷新后可能短暂出现：

```text
token 已恢复
user 还没回来
selectIsAuthenticated 仍然 false
```

更严谨的项目一般会等当前用户请求完成后再标记 app loaded。

## 10. SettingsScreen 的页面权限

设置页需要登录。

`SettingsScreen.js`：

```js
function SettingsScreen() {
  const dispatch = useDispatch();
  const currentUser = useSelector(selectUser);
  const errors = useSelector(selectErrors);
  const isAuthenticated = useSelector(selectIsAuthenticated);

  if (!isAuthenticated) {
    return <Navigate to="/" />;
  }

  return (...);
}
```

如果未登录：

```js
return <Navigate to="/" />;
```

直接跳回首页。

这属于页面级权限控制：

```text
未登录不能访问 settings 页面
```

## 11. 更新用户信息

设置页提交：

```js
const saveSettings = (user) => {
  void dispatch(updateUser(user));
};
```

`updateUser`：

```js
export const updateUser = createAsyncThunk(
  'auth/updateUser',
  async ({ email, username, bio, image, password }, thunkApi) => {
    const {
      user: { token, ...user },
    } = await agent.Auth.save({ email, username, bio, image, password });

    return { token, user };
  },
  {
    condition: (_, { getState }) =>
      selectIsAuthenticated(getState()) && !selectIsLoading(getState()),
  }
);
```

`condition` 表示：

```text
必须已登录
当前没有 auth 请求正在 loading
才允许更新用户
```

成功后仍然走：

```js
.addCase(updateUser.fulfilled, successReducer)
```

所以：

```text
state.auth.token 更新
state.auth.user 更新
Header 上的头像/用户名也会更新
```

## 12. 登出流程

设置页登出：

```js
const logoutUser = () => {
  dispatch(logout());
};
```

`logout`：

```js
logout: () => initialState,
```

所以：

```js
dispatch(logout());
```

会把 auth state 重置为：

```js
{
  status: 'idle';
}
```

同时 `localStorageMiddleware` 监听 logout：

```js
case logout.type:
  window.localStorage.removeItem('jwt');
  agent.setToken(undefined);
  break;
```

登出完整流程：

```text
dispatch(logout())
  -> localStorage 删除 jwt
  -> agent token 清空
  -> auth state 重置
  -> selectIsAuthenticated 变 false
  -> Header 显示未登录导航
```

## 13. 评论权限

评论区有两个权限点。

第一个：未登录不能发表评论。

`CommentSection` 中：

```js
const isAuthenticaded = useSelector(selectIsAuthenticated);
```

未登录时显示：

```text
Sign in or sign up to add comments
```

已登录时才显示：

```jsx
<CommentForm />
```

第二个：提交评论 thunk 自己也检查权限。

`commentsSlice.js`：

```js
condition: (_, { getState }) =>
  selectIsAuthenticated(getState()) && !selectIsLoading(getState());
```

即使某个地方误调用：

```js
dispatch(createComment(...))
```

如果未登录，也不会执行请求。

这比只隐藏 UI 更可靠。

## 14. 删除评论权限

删除评论时：

```js
export const selectIsAuthor = (commentId) =>
  createSelector(
    selectCommentById(commentId),
    selectUser,
    (comment, currentUser) => currentUser?.username === comment?.author.username
  );
```

组件里：

```js
const isAuthor = useSelector(selectIsAuthor(comment.id));
```

只有当前用户是评论作者时显示删除按钮：

```jsx
{
  isAuthor ? <DeleteCommentButton commentId={comment.id} /> : null;
}
```

`removeComment` 也有 condition：

```js
condition: ({ commentId }, { getState }) =>
  selectIsAuthenticated(getState()) &&
  selectCommentsSlice(getState()).ids.includes(commentId) &&
  !selectIsLoading(getState());
```

它检查：

```text
必须登录
评论 id 必须存在于当前 comments state
当前没有 comments 请求 loading
```

注意：前端这里只检查“是否登录”和“评论是否存在”，真正是否有权限删除，后端仍然必须检查。

## 15. 文章作者权限

文章详情中：

```js
const currentUser = useSelector(selectUser);
const article = useSelector((state) => state.article.article);
const isAuthor = currentUser?.username === article?.author.username;
```

如果当前用户是文章作者：

```jsx
{
  isAuthor ? <ArticleActions /> : null;
}
```

才显示：

```text
Edit Article
Delete Article
```

不是作者时，不显示编辑和删除按钮。

但这只是前端隐藏 UI。真正的权限仍然要靠后端接口校验。

## 16. 首页 feed 权限

首页默认 tab：

```js
const defaultTab = isAuthenticated ? 'feed' : 'all';
```

未登录：

```text
默认 Global Feed
```

已登录：

```text
默认 Your Feed
```

`YourFeedTab` 中：

```js
if (!isAuthenticated) {
  return null;
}
```

所以未登录用户看不到 `Your Feed`。

因为 feed 接口通常需要登录 token：

```text
GET /articles/feed
```

## 17. 前端权限和后端权限的关系

这个项目里的前端权限控制主要分两类。

UI 级权限：

```text
未登录不显示评论框
非作者不显示删除按钮
未登录不显示 Your Feed
未登录访问 settings 重定向
```

action/thunk 级权限：

```text
createComment condition 检查登录
removeComment condition 检查登录
updateUser condition 检查登录
```

这些都只是前端权限控制。

真正安全必须靠后端。

原因是前端代码可以被绕过，比如用户可以手动调用接口。

真实权限模型应该是：

```text
前端：
  控制展示
  减少无效操作
  提升用户体验

后端：
  根据 token 验证身份
  判断是否有权执行操作
  拒绝非法请求
```

## 18. 用户态完整流程

登录：

```text
用户登录
  -> login.fulfilled
  -> state.auth.token = token
  -> state.auth.user = user
  -> localStorage 保存 jwt
  -> agent.setToken(token)
  -> Header 显示登录态
```

刷新：

```text
App mount
  -> localStorage.getItem('jwt')
  -> dispatch(appLoad(token))
  -> agent.setToken(token)
  -> dispatch(setToken(token))
  -> dispatch(getUser())
  -> state.auth.user 恢复
  -> selectIsAuthenticated 返回 true
```

登出：

```text
点击 logout
  -> dispatch(logout())
  -> auth state 回到 initialState
  -> localStorage 删除 jwt
  -> agent token 清空
  -> Header 显示未登录态
```

权限判断：

```text
页面级：
  SettingsScreen 未登录 Navigate 到首页

组件级：
  Header 根据登录态切换导航
  CommentSection 根据登录态显示评论框
  ArticleMeta 根据作者显示编辑/删除按钮
  Comment 根据作者显示删除按钮

thunk 级：
  updateUser/createComment/removeComment condition 做前端拦截
```

## 19. 三种用户态存储

这个项目的用户态不是只存在一个地方。

```text
localStorage：
  持久化 token
  页面刷新后还能恢复

agent 内部 token：
  让后续请求带 Authorization header

Redux auth state：
  驱动 UI 显示
  判断权限
  保存当前用户信息
```

三者配合，组成这个项目的登录态和权限控制。
