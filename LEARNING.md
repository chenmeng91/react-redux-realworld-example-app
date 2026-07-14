# React Learning Roadmap for This Project

这个文件用当前项目 `react-redux-realworld-example-app` 作为学习材料。目标不是泛泛学习 React，而是边看真实代码边理解一个前端应用如何组织、运行、请求接口、管理状态和测试。

## 1. 项目整体认识

- 这个项目是什么：RealWorld/Conduit 社交博客示例应用
- 主要功能：注册、登录、文章列表、文章详情、编辑文章、评论、收藏、关注、个人页
- 技术栈：React、Redux Toolkit、React Router、Create React App、Cypress
- 重点文件：
  - `package.json`
  - `src/index.js`
  - `src/components/App.js`
  - `src/agent.js`

## 2. 启动流程和目录结构

- `npm start` 做了什么
- `public/index.html` 和 `src/index.js` 的关系
- React 应用如何挂载到 DOM
- `src/components`、`src/features`、`src/reducers`、`src/app` 分别放什么

## 3. React 组件基础

- 函数组件如何声明和导出
- JSX 是什么
- props 如何传递
- 组件拆分的目的
- 重点文件：
  - `src/components/Header.js`
  - `src/components/Home/index.js`
  - `src/components/ArticlePreview.js`

## 4. React 状态和事件

- `useState` 管理局部状态
- 表单输入如何绑定状态
- 事件处理函数如何写
- 表单提交如何阻止默认行为
- 重点文件：
  - `src/features/auth/AuthScreen.js`
  - `src/components/Editor.js`

## 5. React 生命周期和副作用

- `useEffect` 适合处理什么
- 首次加载时读取 token
- 依赖数组的作用
- 重点文件：
  - `src/components/App.js`

## 6. 路由和页面切换

- React Router 的 `Routes`、`Route`
- URL path 和页面组件的对应关系
- 动态路由参数，例如 `/article/:slug`
- 编程式跳转 `useNavigate`
- 重点文件：
  - `src/components/App.js`
  - `src/features/auth/AuthScreen.js`

## 7. API 请求封装

- 为什么要封装 `agent`
- GET、POST、PUT、DELETE 如何统一处理
- token 如何放进请求头
- 错误响应如何抛出
- 本地开发代理 `/api` 如何避免 CORS
- 重点文件：
  - `src/agent.js`
  - `src/setupProxy.js`

## 8. Redux 基础

- Redux 解决什么问题
- store、reducer、action 的关系
- Redux Toolkit 的 `createSlice`
- selector 的作用
- 重点文件：
  - `src/app/store.js`
  - `src/reducers/common.js`
  - `src/features/auth/authSlice.js`

## 9. 异步状态管理

- `createAsyncThunk` 如何发请求
- pending、fulfilled、rejected 三种状态
- loading 和 errors 如何进入 Redux state
- 重点文件：
  - `src/features/auth/authSlice.js`
  - `src/features/comments/commentsSlice.js`
  - `src/features/tags/tagsSlice.js`

## 10. 登录流程完整拆解（已完成）

- 登录页输入 email/password
- 点击提交触发 `login`
- `login` 调用 API
- 成功后保存 token 和 user
- 页面跳转回首页
- 重点文件：
  - `src/features/auth/AuthScreen.js`
  - `src/features/auth/authSlice.js`
  - `src/agent.js`
  - `src/reducers/common.js`

## 11. 列表页和分页

- 首页文章列表如何加载
- tag 筛选如何影响请求参数
- 分页如何计算 offset
- 重点文件：
  - `src/components/Home/index.js`
  - `src/components/Home/MainView.js`
  - `src/components/ArticleList.js`
  - `src/components/ListPagination.js`
  - `src/reducers/articleList.js`

## 12. 文章详情和评论（已完成）

- 动态 slug 如何获取文章
- Markdown 内容如何渲染
- 评论列表如何加载和提交
- 重点文件：
  - `src/components/Article/index.js`
  - `src/features/comments/CommentSection.js`
  - `src/features/comments/CommentList.js`

## 13. 表单、校验和错误展示

- 登录/注册/编辑文章表单的共性
- 后端错误如何显示到页面
- 重点文件：
  - `src/components/ListErrors.js`
  - `src/features/auth/AuthScreen.js`
  - `src/components/Editor.js`

## 14. 权限和用户态

- 登录态如何判断
- token 如何存储到 `localStorage`
- 只给作者显示编辑/删除按钮
- 重点文件：
  - `src/reducers/common.js`
  - `src/features/auth/authSlice.js`
  - `src/components/Article/ArticleActions.js`
  - `src/components/Header.js`

## 15. 测试

- 单元测试和 e2e 测试的区别
- Cypress 如何访问页面
- Cypress 如何通过 API 准备测试数据
- 重点文件：
  - `src/features/auth/authSlice.spec.js`
  - `src/features/tags/TagsSidebar.spec.js`
  - `cypress/integration/login-spec.js`
  - `cypress/support/index.js`

## 16. 构建和部署

- `npm run build` 做了什么
- 开发环境代理和生产环境 API 配置的区别
- `REACT_APP_BACKEND_URL` 的用途
- 重点文件：
  - `package.json`
  - `README.md`
  - `src/agent.js`

## 建议学习顺序

1. 先跑通项目，确认页面、注册、登录、文章列表都能使用。
2. 从 `src/index.js` 进入，理解应用如何挂载。
3. 看 `src/components/App.js`，理解全局路由。
4. 看登录流程，因为它串起了组件、表单、Redux、API 和跳转。
5. 再看文章列表和文章详情，理解真实业务页面。
6. 最后看测试和构建。

## 当前讲解进度

- [x] 1. 项目整体认识
- [x] 2. 启动流程和目录结构
- [x] 3. React 组件基础
- [x] 4. React 状态和事件
- [x] 5. React 生命周期和副作用
- [x] 6. 路由和页面切换
- [x] 7. API 请求封装
- [x] 8. Redux 基础
- [x] 9. 异步状态管理
- [x] 10. 登录流程完整拆解
- [x] 11. 列表页和分页
- [x] 12. 文章详情和评论
- [x] 13. 表单、校验和错误展示
- [x] 14. 权限和用户态
- [x] 15. 测试
- [x]16. 构建和部署
