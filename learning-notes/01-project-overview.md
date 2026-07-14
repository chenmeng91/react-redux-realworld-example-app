# 01. 项目整体认识

这个项目本质上是一个 React 前端示例应用，但它覆盖了真实业务前端常见的完整链路：页面、路由、表单、登录态、接口请求、列表、详情、评论和测试。

## 应用主线

```text
public/index.html
  -> src/index.js
    -> Redux Provider
    -> React Router
    -> App
      -> Header
      -> Home / Login / Register / Editor / Article / Profile / Settings
```

## 核心文件

- `public/index.html`：HTML 模板，提供 `<div id="root"></div>`。
- `src/index.js`：React 应用入口，负责把组件树挂载到 `root`。
- `src/app/store.js`：创建 Redux store。
- `src/components/App.js`：应用根组件，负责初始化加载和路由分发。
- `src/agent.js`：API 请求封装。

## 第一阶段应该建立的理解

学习这个项目时，先不要陷入每一行代码。先抓住这条主线：

浏览器加载 HTML，React 挂载应用，Redux 提供全局状态，Router 控制页面切换，App 组织业务页面。

这个模型稳定之后，再分别拆解组件、路由、状态、接口和测试。
