# 05. React 生命周期、副作用和外部 Store 更新机制

这一部分对应 `LEARNING.md` 里的“React 生命周期和副作用”，同时融合了关于 `useSelector`、React-Redux、`useSyncExternalStore`、Fiber、标记更新和调度流程的追问。

主要参考文件：

- `src/components/App.js`
- `src/components/Home/index.js`
- `src/components/Editor.js`
- `src/components/Article/index.js`
- `src/features/tags/TagsSidebar.js`

## 1. 什么是副作用

React 组件最核心的工作是：

```text
根据 props / state 返回 UI
```

但真实应用里，组件还会做一些“渲染 UI 之外的事情”，例如：

- 请求接口
- 读取 `localStorage`
- 修改浏览器状态
- 订阅事件
- 进入页面时加载数据
- 离开页面时清理数据
- 根据某个状态变化执行额外逻辑

这些就叫副作用。

在 React 函数组件中，处理副作用主要使用：

```js
useEffect(...)
```

可以先记住：

```text
useEffect 用来处理渲染之外的事情
```

## 2. `useEffect` 的基本写法

```js
useEffect(() => {
  // 执行副作用
}, [dependencies]);
```

第二个参数是依赖数组，决定 effect 什么时候执行。

常见三种形式：

```js
useEffect(() => {
  ...
}, []);
```

组件挂载后执行一次。

```js
useEffect(() => {
  ...
}, [value]);
```

组件挂载后执行一次，之后 `value` 变化时再次执行。

```js
useEffect(() => {
  ...
});
```

没有依赖数组，每次渲染后都会执行。这个项目里基本不这样写，因为容易造成不必要的执行。

## 3. `App` 中的首次加载

`src/components/App.js` 中：

```js
useEffect(() => {
  const token = window.localStorage.getItem('jwt');
  dispatch(appLoad(token));
}, []);
```

含义：

```text
App 组件第一次加载后
  -> 从 localStorage 读取 jwt
  -> dispatch(appLoad(token))
  -> 尝试恢复登录状态
```

依赖数组是 `[]`，表示这段逻辑只需要在应用启动时执行一次。

这类场景类似 class 组件时代的：

```js
componentDidMount();
```

## 4. `App` 中监听 `redirectTo`

`App.js` 中还有：

```js
const redirectTo = useSelector((state) => state.common.redirectTo);

useEffect(() => {
  if (redirectTo) {
    dispatch(clearRedirect());
  }
}, [redirectTo]);
```

这里的 `redirectTo` 不是 `useState` 创建的局部状态，而是 Redux 全局状态的一部分：

```text
state.common.redirectTo
```

它通过 React-Redux 的 `useSelector` 读取：

```js
useSelector((state) => state.common.redirectTo);
```

这个 effect 的含义是：

```text
当 redirectTo 变化时
  -> 如果 redirectTo 有值
  -> dispatch(clearRedirect())
  -> 清除 redirectTo
```

依赖数组 `[redirectTo]` 表示：

```text
组件挂载后执行一次
之后 redirectTo 变化时再次执行
```

## 5. `useState`、props、Redux state 都可能触发重新渲染

React 组件重新渲染不只来自 `useState` 和 props。

常见来源包括：

- 组件自己的 `useState` 状态变化
- props 变化
- 父组件重新渲染
- Context 值变化
- `useReducer` 状态变化
- `useSelector` 订阅到的 Redux state 变化
- 其他通过 `useSyncExternalStore` 接入的外部 store 变化

所以：

```js
const redirectTo = useSelector((state) => state.common.redirectTo);
```

属于：

```text
组件订阅的外部状态发生变化，触发重新渲染
```

## 6. React、Redux store、React-Redux 的关系

三者职责不同：

```text
React：负责组件渲染
Redux store：负责保存外部全局状态
React-Redux：负责把 Redux store 接到 React 组件里
```

Redux store 提供：

```js
store.getState();
store.dispatch(action);
store.subscribe(listener);
```

含义：

```text
getState：读取当前全局状态
dispatch：发送 action 并更新 state
subscribe：监听 state 变化
```

React 本身不知道 Redux 是什么，Redux 也不知道 React 是什么。

React-Redux 是中间桥梁：

```text
Provider：把 store 提供给 React 组件树
useSelector：从 store 中选择数据，并订阅变化
useDispatch：拿到 store.dispatch，用来发送 action
```

## 7. `useSelector` 如何读取 Redux state

在组件中：

```js
const redirectTo = useSelector((state) => state.common.redirectTo);
```

首次渲染时发生：

```text
React 调用 App()
  -> App 调用 useSelector(...)
  -> React-Redux 从 Provider 中拿到 Redux store
  -> 调用 store.getState()
  -> 执行 selector: state.common.redirectTo
  -> 得到 redirectTo
  -> App 使用 redirectTo 渲染
```

所以：

```text
React 负责执行组件函数
React-Redux 负责帮组件读取 Redux store
Redux store 提供 state 数据
```

## 8. `useSelector` 如何触发组件重新渲染

当某处执行：

```js
dispatch(action);
```

完整流程是：

```text
1. 组件或代码调用 dispatch(action)
2. Redux store 接收到 action
3. Redux store 调用 reducer
   oldState + action -> newState
4. Redux store 保存 newState
5. Redux store 通知 subscribe 注册的监听者
6. React-Redux 通过 useSelector 订阅了 store，因此收到通知
7. React-Redux 重新执行 selector
8. 比较新旧 selected value
9. 如果 selected value 变了，通知 React 这个组件需要更新
10. React 重新执行组件函数
```

套回 `redirectTo`：

```text
某个 action 改变 state.common.redirectTo
  -> Redux store 更新
  -> React-Redux 收到 store 变化通知
  -> 重新计算 state.common.redirectTo
  -> 发现 redirectTo 变了
  -> React 重新渲染 App
  -> useEffect([redirectTo]) 执行
```

## 9. `useSyncExternalStore` 是什么

`useSyncExternalStore` 是 React 18 提供的 Hook，专门用于让 React 组件订阅外部 store。

它解决的问题是：

```text
状态不在 React 内部
但 React 组件想读取它
并且外部状态变化时组件要重新渲染
```

基础 API：

```js
const value = useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);
```

核心参数：

- `subscribe`：告诉 React 如何订阅外部 store 的变化。
- `getSnapshot`：告诉 React 如何读取当前外部状态。
- `getServerSnapshot`：服务端渲染使用，普通客户端项目可以先不关注。

Redux store 天然就有：

```js
store.subscribe;
store.getState;
```

因此可以接入 React 的外部 store 机制。

## 10. `useSyncExternalStoreWithSelector` 和 `useSyncExternalStore`

`useSyncExternalStore` 是基础版。

它通常读取整个外部状态快照：

```js
useSyncExternalStore(store.subscribe, store.getState);
```

`useSyncExternalStoreWithSelector` 是增强版，它底层仍然基于 `useSyncExternalStore`，但额外支持：

- selector
- equalityFn
- selected value 缓存

概念上类似：

```js
useSyncExternalStoreWithSelector(
  subscribe,
  getSnapshot,
  getServerSnapshot,
  selector,
  equalityFn
);
```

React-Redux 的 `useSelector` 内部使用的是这个增强版。

它的目标是：

```text
订阅整个 Redux store
但组件只关心 selector 选出来的那一小块数据
```

例如：

```js
useSelector((state) => state.common.redirectTo);
```

只关心：

```text
state.common.redirectTo
```

而不是整个 Redux state。

## 11. 为什么在 `App` 中看不到 `useSyncExternalStore`

因为它被 React-Redux 封装在 `useSelector` 内部。

业务代码写的是：

```js
const redirectTo = useSelector((state) => state.common.redirectTo);
```

内部大致是：

```js
useSyncExternalStoreWithSelector(
  subscription.addNestedSub,
  store.getState,
  getServerState || store.getState,
  selector,
  equalityFn
);
```

所以调用链是：

```text
App
  -> useSelector
  -> useSyncExternalStoreWithSelector
  -> useSyncExternalStore
  -> React 内部调度更新
```

## 12. `useSelector` 是否拿到了组件实例

没有。

函数组件没有传统 class 组件那样的组件实例。

不是：

```text
useSelector 找到 App 实例，然后调用 App 的某个方法
```

而是：

```text
React 正在渲染 App
  -> App 调用 useSelector
  -> useSelector 调用 React hook
  -> React 知道这个 hook 属于当前正在渲染的 App Fiber
```

React 内部维护“当前正在渲染的组件”。

所以：

```text
组件渲染时调用 hook
React 把 hook 记录到当前组件对应的 Fiber 上
```

## 13. 组件和 hook 的对应关系如何维护

React 内部靠 Fiber 和 hook 调用顺序维护对应关系。

可以把 Fiber 理解成 React 内部给组件建立的工作记录：

```text
Fiber(App)
  -> props
  -> hooks
  -> 子节点
  -> 更新标记
```

当 React 渲染 `App`：

```js
function App() {
  const redirectTo = useSelector(...);
  const appLoaded = useSelector(...);
  useEffect(...);
}
```

React 内部大致记录为：

```text
Fiber(App)
  hook0 -> 第一个 useSelector
  hook1 -> 第二个 useSelector
  hook2 -> useEffect
```

下一次渲染时，React 仍然按顺序对应这些 hook。

这也是为什么 hook 不能写在不稳定的 `if`、`for` 里。

因为 React 不是通过变量名找 hook，而是通过：

```text
当前正在渲染的 Fiber + hook 调用顺序
```

维护对应关系。

## 14. `useSelector` 建立的是“组件订阅”吗

可以口语上说：

```text
App 组件订阅了 redirectTo
```

但更准确是：

```text
App 渲染期间调用的 useSelector hook 建立了 store 订阅
这个 hook 状态被 React 记录在 App 对应的 Fiber 上
```

如果一个组件里有两个 `useSelector`：

```js
const redirectTo = useSelector((state) => state.common.redirectTo);
const appLoaded = useSelector((state) => state.common.appLoaded);
```

可以理解为：

```text
第一个 useSelector 关心 redirectTo
第二个 useSelector 关心 appLoaded
```

任意一个订阅值变化，React 最终重新渲染的是整个 `App()` 函数。

## 15. 首次渲染建立订阅，后续 store 变化触发更新

这个过程分两个阶段。

阶段 1：组件渲染时建立订阅。

```text
React 调用 App()
  -> App 调用 useSelector(...)
  -> useSelector 调用 useSyncExternalStoreWithSelector(...)
  -> useSyncExternalStoreWithSelector 向 Redux store 注册订阅
  -> React 记录这个订阅属于 App 这个 Fiber
```

阶段 2：store 变化时触发更新。

```text
dispatch(action)
  -> Redux store 更新
  -> 之前注册的 listener 被调用
  -> useSyncExternalStore 检查 snapshot / selector 结果
  -> 如果结果变了，通知 React
  -> React 安排 App 对应 Fiber 重新渲染
  -> React 再次调用 App()
```

所以不是：

```text
为了重新渲染，先去调用组件里的 useSelector
```

而是：

```text
之前渲染时已经通过 useSelector 建好了订阅
store 变化时触发订阅回调
订阅回调通知 React 更新
React 决定重新渲染后，才再次调用组件函数和 hook
```

## 16. 是否有“组件标脏”的过程

概念上有。

可以理解为：

```text
外部 store 变化
  -> 订阅回调通知 React
  -> React 把对应 Fiber 标记为需要更新
  -> React 调度重新渲染
```

但源码层面不只是简单的：

```js
component.dirty = true;
```

React 维护的是 Fiber 树。

它会记录：

- update queue
- lanes
- childLanes
- flags

学习阶段可以先用这个模型：

```text
状态变了
  -> 对应 Fiber 标记需要更新
  -> React 调度
  -> render phase 重新计算
  -> commit phase 更新 DOM
  -> 浏览器 paint
```

更严谨地说：

```text
React 不是标记组件对象脏
而是标记 Fiber 树上的更新优先级和待处理更新
```

## 17. React 是否能随时更新 UI

React 不能跳过浏览器或系统 UI 的渲染限制。

最终显示到屏幕仍然要经过浏览器渲染管线：

```text
JavaScript 执行
  -> React 计算新的 UI
  -> React 修改 DOM
  -> 浏览器 style/layout/paint/composite
  -> 屏幕刷新显示
```

React 控制的是：

- 什么时候计算组件树
- 什么时候提交 DOM 变化
- 如何批处理和调度更新

浏览器控制的是：

- 样式计算
- 布局
- 绘制
- 合成
- 屏幕刷新

所以：

```text
React 可以调度 JS 层的 UI 计算和 DOM 提交
但最终显示到屏幕，要等浏览器绘制
```

## 18. `Home` 中的加载和清理

`src/components/Home/index.js` 中：

```js
useEffect(() => {
  const defaultTab = isAuthenticated ? 'feed' : 'all';
  const fetchArticles = dispatch(changeTab(defaultTab));

  return () => {
    dispatch(homePageUnloaded());
    fetchArticles.abort();
  };
}, []);
```

组件加载时：

```text
判断用户是否登录
  -> 已登录默认 tab 是 feed
  -> 未登录默认 tab 是 all
  -> dispatch(changeTab(defaultTab))
  -> 加载文章列表
```

组件卸载时执行清理函数：

```js
return () => {
  dispatch(homePageUnloaded());
  fetchArticles.abort();
};
```

含义：

```text
离开首页
  -> 清理首页文章列表状态
  -> 如果请求还没完成，中止请求
```

`useEffect` 里 `return` 的函数不是渲染 UI，而是清理副作用。

## 19. `Editor` 中根据 `slug` 加载文章

`src/components/Editor.js` 中：

```js
useEffect(() => {
  reset();
  if (slug) {
    dispatch(getArticle(slug));
  }
}, [slug]);
```

`slug` 来自 URL：

```js
const { slug } = useParams();
```

含义：

```text
进入编辑页或 slug 变化时
  -> 先重置表单
  -> 如果有 slug，说明是在编辑已有文章
  -> 请求文章详情
```

依赖是 `[slug]`，表示当 URL 中的 slug 变化时，重新执行这个副作用。

## 20. `Editor` 中根据 `article` 填充表单

```js
useEffect(reset, [article]);
```

含义：

```text
当 article 数据变化时
  -> 执行 reset
  -> 把文章数据填到表单里
```

这是因为请求文章详情是异步的：

```text
进入 /editor/:slug
  -> 第一次渲染时 article 可能还没有
  -> dispatch(getArticle(slug))
  -> 接口返回
  -> Redux 中的 article 更新
  -> 组件重新渲染
  -> useEffect(reset, [article]) 执行
  -> 表单填入 title、description、body、tagList
```

## 21. `Editor` 卸载时清理

```js
useEffect(() => () => dispatch(articlePageUnloaded()), []);
```

展开写是：

```js
useEffect(() => {
  return () => {
    dispatch(articlePageUnloaded());
  };
}, []);
```

含义：

```text
Editor 组件卸载时
  -> 清理 article 页面状态
```

这个 effect 本体没有做事，只返回了一个清理函数。

## 22. 本节重点

关于 `useEffect`：

```text
1. useEffect 用来处理渲染之外的副作用。
2. [] 表示组件挂载后执行一次。
3. [value] 表示挂载后执行一次，并在 value 变化时再次执行。
4. useEffect 里 return 的函数是清理函数。
5. 请求数据、读 localStorage、订阅事件、页面卸载清理，适合放进 useEffect。
6. 能在渲染时直接算出来的值，不要为了“同步状态”乱放 useEffect。
```

关于 React-Redux 和外部 store：

```text
1. Redux store 是 React 外部状态。
2. React-Redux 是 React 和 Redux 之间的桥。
3. useSelector 内部通过 useSyncExternalStoreWithSelector 订阅 Redux store。
4. useSyncExternalStoreWithSelector 底层基于 useSyncExternalStore。
5. React 把 hook 状态记录到当前组件 Fiber 上。
6. 外部 store 变化时，订阅回调通知 React。
7. React 标记对应 Fiber 需要更新，并调度重新渲染。
8. React 不能跳过浏览器绘制管线，最终显示仍要等待浏览器 paint。
```

完整心智模型：

```text
组件渲染
  -> 调用 useSelector / useEffect 等 hook
  -> React 把 hook 记录到当前 Fiber
  -> useSelector 建立外部 store 订阅

Redux store 更新
  -> listener 被调用
  -> selector 结果变化
  -> React 标记 Fiber 需要更新
  -> React 调度 render phase
  -> 重新执行组件函数
  -> commit phase 更新 DOM
  -> 浏览器 paint
```
