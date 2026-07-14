# 06. 路由和页面切换

这一部分对应 `LEARNING.md` 里的“路由和页面切换”，同时融合了关于 React Router、浏览器地址变化、WebView 拦截、嵌套路由、`NavLink`、`Suspense` 和懒加载的追问。

主要参考文件：

- `src/index.js`
- `src/components/App.js`
- `src/components/Header.js`
- `src/features/auth/AuthScreen.js`
- `src/components/Editor.js`
- `src/components/Article/index.js`

## 1. Router 如何接入项目

`src/index.js` 中：

```js
import { BrowserRouter as Router } from 'react-router-dom';
```

然后：

```jsx
<Provider store={store}>
  <Router>
    <App />
  </Router>
</Provider>
```

`Router` 包住了 `App`，表示：

```text
App 以及它下面的所有组件都可以使用路由能力
```

例如：

- `<Routes />`
- `<Route />`
- `<Link />`
- `<NavLink />`
- `useNavigate()`
- `useParams()`
- `useLocation()`

如果没有 `<Router>` 包裹，这些 API 就不能正常工作。

## 2. `Routes` 和 `Route` 定义页面

`src/components/App.js` 中：

```jsx
<Routes>
  <Route exact path="/" element={<Home />} />
  <Route path="/login" element={<AuthScreen />} />
  <Route path="/register" element={<AuthScreen isRegisterScreen />} />
  <Route path="/editor/:slug" element={<Editor />} />
  <Route path="/editor" element={<Editor />} />
  <Route path="/article/:slug" element={<Article />} />
  <Route path="/settings" element={<SettingsScreen />} />
  <Route path="/@:username/favorites" element={<Profile isFavoritePage />} />
  <Route path="/@:username" element={<Profile />} />
</Routes>
```

可以把它理解成一张路由表：

```text
URL 路径                  显示组件
/                         Home
/login                    AuthScreen
/register                 AuthScreen，注册模式
/editor                   Editor，创建文章
/editor/:slug             Editor，编辑文章
/article/:slug            Article，文章详情
/settings                 SettingsScreen
/@:username               Profile，用户主页
/@:username/favorites     Profile，收藏页
```

`Routes` 是路由规则容器。

它的作用是：

```text
根据当前浏览器 URL，从内部 Route 中选出最匹配的一条，然后渲染它的 element
```

`Route` 是一条路由规则。

例如：

```jsx
<Route path="/login" element={<AuthScreen />} />
```

含义：

```text
如果当前 URL 是 /login，就渲染 AuthScreen
```

React Router v6 使用：

```jsx
element={<AuthScreen />}
```

而不是旧版本的：

```jsx
component = { AuthScreen };
```

## 3. `element` 中可以传 props

注册页路由：

```jsx
<Route path="/register" element={<AuthScreen isRegisterScreen />} />
```

这里的：

```jsx
isRegisterScreen;
```

是普通 React props，不是 URL 参数，也不是 React Router 自动生成的参数。

它等价于：

```jsx
<AuthScreen isRegisterScreen={true} />
```

所以 `AuthScreen` 中：

```js
function AuthScreen({ isRegisterScreen }) {
```

拿到的是：

```js
isRegisterScreen === true;
```

登录页：

```jsx
<Route path="/login" element={<AuthScreen />} />
```

没有传这个 props，因此：

```js
isRegisterScreen === undefined;
```

在条件判断中相当于 false。

这就是同一个 `AuthScreen` 同时实现登录页和注册页的方式：

```text
/login     -> <AuthScreen />                  -> 登录页
/register  -> <AuthScreen isRegisterScreen /> -> 注册页
```

## 4. 动态路由参数

```jsx
<Route path="/article/:slug" element={<Article />} />
```

这里的：

```text
:slug
```

表示动态参数。

它可以匹配：

```text
/article/hello-world
/article/react-router-guide
/article/123
```

组件里通过：

```js
const { slug } = useParams();
```

读取。

例如访问：

```text
/article/my-post
```

组件里得到：

```js
slug === 'my-post';
```

`Editor` 也使用了动态参数：

```jsx
<Route path="/editor/:slug" element={<Editor />} />
<Route path="/editor" element={<Editor />} />
```

含义：

```text
/editor       -> 创建文章，没有 slug
/editor/:slug -> 编辑文章，有 slug
```

`Editor` 中：

```js
const { slug } = useParams();
```

再根据 `slug` 判断创建还是更新：

```js
dispatch(slug ? updateArticle(article) : createArticle(article));
```

## 5. `Link` 和前端页面跳转

`Header.js` 中：

```jsx
<Link to="/login" className="nav-link">
  Sign in
</Link>
```

`Link` 类似 HTML 的 `<a>`，但不会触发整页刷新。

它做的是前端路由跳转：

```text
点击 Link
  -> 阻止浏览器默认整页跳转
  -> 使用 history.pushState 修改地址
  -> React Router 感知 location 变化
  -> Routes 重新匹配
  -> React 渲染对应页面组件
```

所以 React 项目中站内跳转通常用：

```jsx
<Link to="/login" />
```

而不是：

```html
<a href="/login"></a>
```

## 6. 浏览器地址变了，为什么不一定请求新页面

浏览器地址变化有两种情况。

第一种：真正导航。

例如直接输入地址：

```text
http://localhost:4100/login
```

或者普通链接：

```html
<a href="/login">Login</a>
```

浏览器会请求服务器。

在 SPA 项目里，服务器通常返回同一个 `index.html`，然后 React Router 根据当前 URL 渲染对应页面。

流程：

```text
浏览器请求 /login
  -> dev server 返回 index.html
  -> 加载 React JS
  -> BrowserRouter 读取 location.pathname = /login
  -> Routes 匹配 /login
  -> 渲染 AuthScreen
```

第二种：React Router 前端跳转。

例如：

```jsx
<Link to="/login" />
```

或者：

```js
navigate('/login');
```

它使用浏览器 History API：

```js
history.pushState(...)
```

这会改变地址栏，但不会请求新的 HTML 页面。

## 7. 后退/前进时 React Router 如何感知

用户点击浏览器后退或前进按钮时，浏览器会触发：

```js
popstate;
```

React Router 的 `BrowserRouter` 会监听这个事件。

流程：

```text
用户点击后退
  -> 浏览器 URL 回到上一个地址
  -> 浏览器触发 popstate
  -> React Router 监听到 popstate
  -> 更新自己的 location 状态
  -> Routes 重新匹配
  -> React 渲染对应页面
```

可以简化理解：

```text
BrowserRouter = 监听浏览器地址变化 + 把当前地址提供给 Routes
```

## 8. URL 入栈的是地址，不是组件实例

从 `/` 跳到 `/login`：

```text
/ -> /login
```

浏览器 history 中保存的是 URL 记录：

```text
history stack:
1. /
2. /login
```

不是把旧的 `Home` 组件实例放进栈里。

组件层面更像：

```text
Home 卸载
AuthScreen 挂载
```

后退时：

```text
/login -> /
```

React Router 根据 URL 重新匹配 `/`，然后重新渲染 `Home`。

可能保留的是：

- Redux store 中的数据
- localStorage 中的数据
- 浏览器 history 中的 URL

但旧组件实例本身通常已经卸载。

## 9. 是否所有页面代码一开始都下载了

不一定。

如果没有代码分割，可以理解为：

```text
应用代码下载到浏览器
Router 根据 URL 决定渲染哪个组件
```

但这个项目用了 `React.lazy`：

```js
const Article = lazy(() => import('../components/Article'));
const Editor = lazy(() => import('../components/Editor'));
const AuthScreen = lazy(() => import('../features/auth/AuthScreen'));
const Profile = lazy(() => import('../components/Profile'));
const SettingsScreen = lazy(() => import('../features/auth/SettingsScreen'));
```

这叫代码分割 / 懒加载。

含义：

```text
首页需要的代码先下载
某些页面组件代码，等访问对应路由时再下载
```

例如访问 `/login` 时，Router 匹配 `AuthScreen`。

如果 `AuthScreen` 的 JS chunk 还没下载，就先下载，下载完成后再渲染。

## 10. `Suspense` 和懒加载页面

`App.js` 中：

```jsx
<Suspense fallback={<p>Loading...</p>}>
  <Routes>...</Routes>
</Suspense>
```

`Suspense` 是 React 的等待边界。

它的作用是：

```text
如果子组件暂时还没准备好，就先显示 fallback
```

在这个项目里，它主要配合 `React.lazy` 使用。

流程：

```text
用户访问 /editor
  -> Routes 匹配 /editor
  -> 要渲染 Editor
  -> Editor 是 lazy 组件
  -> 如果 Editor chunk 还没下载完成
  -> Suspense 显示 fallback: Loading...
  -> chunk 下载完成
  -> React 渲染 Editor
```

当前结构是：

```jsx
<>
  <Header />
  <Suspense fallback={<p>Loading...</p>}>
    <Routes>...</Routes>
  </Suspense>
</>
```

`Header` 在 `Suspense` 外面，所以加载期间：

```text
Header 继续显示
Routes 区域显示 Loading...
```

不是整个页面都只显示 `Loading...`。

`Suspense` 包住哪里，fallback 就替换哪里。

## 11. `useNavigate`

有些跳转不是用户点击链接，而是代码逻辑决定的。

例如 `AuthScreen.js`：

```js
const navigate = useNavigate();
```

登录或注册成功后：

```js
if (isRegisterScreen) {
  navigate('/login');
} else {
  navigate('/');
}
```

含义：

```text
注册成功 -> 跳转 /login
登录成功 -> 跳转 /
```

`useNavigate()` 每个组件调用时，都会在当前组件中拿到一个 `navigate` 函数。

不同组件里的 `navigate` 不是页面专属对象，也不是简单的全局变量。

更准确地说：

```text
useNavigate 从 Router Context 中读取路由能力
返回一个可以修改当前路由的函数
```

多个组件调用 `useNavigate()`，最终操作的是同一个 `BrowserRouter` 管理的 history。

类比：

```text
useDispatch() 返回 dispatch，不同组件都能 dispatch 到同一个 Redux store
useNavigate() 返回 navigate，不同组件都能导航同一个 Router
```

## 12. `Link` 和 `useNavigate` 的区别

```text
Link：用户点击跳转
useNavigate：代码逻辑跳转
```

例如：

```jsx
<Link to="/login">Sign in</Link>
```

适合导航栏、文章标题、普通链接。

```js
navigate('/');
```

适合登录成功、提交成功、删除成功之后自动跳转。

## 13. `NavLink`

`NavLink` 可以理解成：

```text
Link + 当前路由是否激活的判断
```

普通 `Link` 只负责跳转。

`NavLink` 除了跳转，还能根据当前 URL 判断自己是否 active。

适合：

- 顶部导航
- 侧边栏菜单
- tab 切换
- 当前页面高亮

基本写法：

```jsx
<NavLink
  to="/settings"
  className={({ isActive }) => (isActive ? 'nav-link active' : 'nav-link')}
>
  Settings
</NavLink>
```

当当前 URL 匹配 `/settings` 时：

```js
isActive === true;
```

否则：

```js
isActive === false;
```

首页链接通常要加 `end`：

```jsx
<NavLink
  to="/"
  end
  className={({ isActive }) => (isActive ? 'nav-link active' : 'nav-link')}
>
  Home
</NavLink>
```

`end` 表示必须完整匹配 `/`。

否则 `/login`、`/settings` 这类路径也都以 `/` 开头，首页可能错误高亮。

### `NavLink` 完整例子

```jsx
import React from 'react';
import { BrowserRouter, Routes, Route, NavLink } from 'react-router-dom';

function App() {
  return (
    <BrowserRouter>
      <Header />

      <main style={{ padding: 24 }}>
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/articles" element={<Articles />} />
          <Route path="/settings" element={<Settings />} />
        </Routes>
      </main>
    </BrowserRouter>
  );
}

function Header() {
  return (
    <nav style={{ display: 'flex', gap: 16, padding: 24 }}>
      <NavLink
        to="/"
        end
        style={({ isActive }) => ({
          color: isActive ? 'green' : 'gray',
          fontWeight: isActive ? 'bold' : 'normal',
          textDecoration: 'none',
        })}
      >
        Home
      </NavLink>

      <NavLink
        to="/articles"
        style={({ isActive }) => ({
          color: isActive ? 'green' : 'gray',
          fontWeight: isActive ? 'bold' : 'normal',
          textDecoration: 'none',
        })}
      >
        Articles
      </NavLink>

      <NavLink
        to="/settings"
        style={({ isActive }) => ({
          color: isActive ? 'green' : 'gray',
          fontWeight: isActive ? 'bold' : 'normal',
          textDecoration: 'none',
        })}
      >
        Settings
      </NavLink>
    </nav>
  );
}

function Home() {
  return <h1>Home Page</h1>;
}

function Articles() {
  return <h1>Articles Page</h1>;
}

function Settings() {
  return <h1>Settings Page</h1>;
}

export default App;
```

`isActive` 不是 `NavLink` 自己保存的状态。

它是 React Router 根据当前 URL 和 `to` 重新计算出来的。

例如从 `/` 跳到 `/articles`：

```text
URL 从 / 变成 /articles
  -> React Router 更新 location
  -> 所有 NavLink 重新计算 isActive
  -> Home isActive = false
  -> Articles isActive = true
```

所以 active 状态的唯一事实来源是：

```text
当前 URL
```

## 14. 嵌套路由

嵌套路由用于多个页面共享一层布局，但内部内容根据子路径变化。

例如：

```text
/settings/profile
/settings/security
/settings/billing
```

它们都可以共用 `SettingsLayout`。

路由写法：

```jsx
<Routes>
  <Route path="/settings" element={<SettingsLayout />}>
    <Route path="profile" element={<ProfileSettings />} />
    <Route path="security" element={<SecuritySettings />} />
    <Route path="billing" element={<BillingSettings />} />
  </Route>
</Routes>
```

父组件中使用：

```jsx
<Outlet />
```

表示子路由内容渲染的位置。

完整例子：

```jsx
import {
  BrowserRouter,
  Routes,
  Route,
  Link,
  NavLink,
  Outlet,
} from 'react-router-dom';

function App() {
  return (
    <BrowserRouter>
      <nav>
        <Link to="/">Home</Link>
        {' | '}
        <Link to="/settings/profile">Settings</Link>
      </nav>

      <Routes>
        <Route path="/" element={<Home />} />

        <Route path="/settings" element={<SettingsLayout />}>
          <Route index element={<ProfileSettings />} />
          <Route path="profile" element={<ProfileSettings />} />
          <Route path="security" element={<SecuritySettings />} />
          <Route path="billing" element={<BillingSettings />} />
        </Route>

        <Route path="*" element={<NotFound />} />
      </Routes>
    </BrowserRouter>
  );
}

function SettingsLayout() {
  return (
    <div>
      <h1>Settings</h1>

      <div style={{ display: 'flex', gap: 24 }}>
        <aside style={{ width: 160 }}>
          <ul>
            <li>
              <NavLink to="profile">Profile</NavLink>
            </li>
            <li>
              <NavLink to="security">Security</NavLink>
            </li>
            <li>
              <NavLink to="billing">Billing</NavLink>
            </li>
          </ul>
        </aside>

        <main>
          <Outlet />
        </main>
      </div>
    </div>
  );
}

function Home() {
  return <h1>Home</h1>;
}

function ProfileSettings() {
  return <h2>Profile Settings</h2>;
}

function SecuritySettings() {
  return <h2>Security Settings</h2>;
}

function BillingSettings() {
  return <h2>Billing Settings</h2>;
}

function NotFound() {
  return <h1>404</h1>;
}
```

访问结果：

```text
/settings/profile  -> SettingsLayout + ProfileSettings
/settings/security -> SettingsLayout + SecuritySettings
/settings/billing  -> SettingsLayout + BillingSettings
```

一句话：

```text
嵌套路由 = 父路由负责公共布局，子路由负责局部内容，Outlet 是子路由内容的插槽。
```

## 15. `Navigate` 和路由守卫

`useNavigate` 是在事件或逻辑中调用函数跳转。

`<Navigate />` 是渲染时跳转。

例如未登录时重定向：

```jsx
function RequireAuth({ children }) {
  const isAuthenticated = useSelector(selectIsAuthenticated);

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  return children;
}
```

使用：

```jsx
<Route
  path="/settings"
  element={
    <RequireAuth>
      <SettingsScreen />
    </RequireAuth>
  }
/>
```

`replace` 表示替换当前历史记录，而不是新增一条记录。

## 16. 404 兜底路由

当前项目没有明显的 404 兜底路由。

通常可以加：

```jsx
<Route path="*" element={<NotFound />} />
```

`*` 表示：

```text
没有其他路由匹配时，显示 NotFound
```

## 17. 查询参数和 `useSearchParams`

动态路径参数用：

```js
useParams();
```

例如：

```text
/article/:slug
```

查询参数不是 `useParams` 读的。

例如：

```text
/articles?page=2&tag=react
```

应该用：

```js
const [searchParams, setSearchParams] = useSearchParams();

const page = searchParams.get('page');
const tag = searchParams.get('tag');
```

## 18. `useLocation`

`useLocation()` 可以读取当前 URL 信息：

```js
const location = useLocation();
```

常见字段：

```js
location.pathname;
location.search;
location.hash;
location.state;
```

适合：

- 根据当前路径做逻辑
- 路由变化时做埋点
- 登录后跳回来源页
- 和 WebView / 原生容器通信

## 19. React Router 和 Android WebView 拦截

React Router 的 `<Link>` 和 `useNavigate` 通常使用：

```js
history.pushState(...)
```

它不是一次真正的网络导航。

因此 Android WebView 常见的：

```kotlin
shouldOverrideUrlLoading(...)
```

不一定能拦截到 React Router 的 SPA 路由跳转。

如果要让 WebView 稳定拦截，一般要触发真正导航：

```js
window.location.href = 'myapp://open/login';
```

或者普通：

```html
<a href="myapp://open/login">Open</a>
```

这样 WebView 更稳定进入：

```kotlin
shouldOverrideUrlLoading(...)
```

但不建议为了普通站内页面切换都使用真正导航。

因为真正导航会：

- 整页刷新
- React 应用重新初始化
- 内存中的组件状态丢失
- Redux 如果没有持久化也会重置
- 性能和体验变差

更推荐：

```text
普通页面切换：React Router
需要原生拦截：特殊 scheme 或 JSBridge
需要监听所有路由变化：useLocation + JSBridge
```

例如：

```jsx
import { useEffect } from 'react';
import { useLocation } from 'react-router-dom';

function RouteBridge() {
  const location = useLocation();

  useEffect(() => {
    window.Android?.onRouteChange(location.pathname + location.search);
  }, [location]);

  return null;
}
```

放到 Router 里面：

```jsx
<Router>
  <RouteBridge />
  <App />
</Router>
```

## 20. 真正导航在 React 中能不能用

可以用。

例如：

```js
window.location.href = '/login';
```

或者：

```jsx
<a href="/login">Login</a>
```

这会触发浏览器真正请求页面。

只是站内页面切换通常不推荐，因为会破坏 SPA 体验。

适合真正导航的场景：

- 跳到外部网站
- 跳到支付页面
- 跳到 OAuth 登录页
- 下载文件
- 打开 `myapp://` 这种原生 scheme
- 刻意让 WebView 或浏览器拦截
- 需要整页刷新清空状态

## 21. 本节重点

React Router 的基础模型：

```text
BrowserRouter 提供路由上下文
Routes 根据当前 URL 选择匹配的 Route
Route 定义 path 和 element 的映射
Link / NavLink 负责用户点击跳转
useNavigate 负责代码逻辑跳转
useParams 读取动态路径参数
useLocation 读取当前 location
useSearchParams 读取查询参数
Suspense + lazy 支持页面代码懒加载
```

站内页面切换流程：

```text
点击 Link / 调用 navigate
  -> history.pushState 修改 URL
  -> 不请求新 HTML
  -> BrowserRouter 感知 location 变化
  -> Routes 重新匹配
  -> React 渲染对应 element
```

直接访问或刷新流程：

```text
浏览器请求 /login
  -> 服务器返回 index.html
  -> React 应用启动
  -> BrowserRouter 读取当前 URL
  -> Routes 匹配 /login
  -> 渲染 AuthScreen
```

最终一句话：

```text
React Router 让 URL 和 React 组件建立映射；
站内切换通常不刷新页面；
真正导航仍然可以用，但主要用于外部跳转、原生拦截或必须整页加载的场景。
```
