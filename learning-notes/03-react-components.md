# 03. React 组件基础

这一部分对应 `LEARNING.md` 里的“React 组件基础”，主要参考这些文件：

- `src/components/Header.js`
- `src/components/Home/index.js`
- `src/components/ArticlePreview.js`
- `src/components/Home/Banner.js`

## 1. 组件是什么

React 组件本质上是一个函数，返回一段 UI。

例如：

```js
function Header() {
  return <nav className="navbar navbar-light">...</nav>;
}
```

可以先简单理解为：

```text
组件 = 一个返回页面结构的函数
```

在 React 里，组件名通常使用大写，例如 `Header`、`Home`、`Banner`。

## 2. JSX 是什么

组件里返回的结构：

```jsx
<nav className="navbar navbar-light">
  <div className="container">...</div>
</nav>
```

看起来像 HTML，但它是 JSX。JSX 允许在 JavaScript 里写类似 HTML 的页面结构。

几个常见规则：

- React 里写 `className`，不是 HTML 的 `class`。
- JSX 里用 `{}` 插入 JavaScript 表达式。
- JSX 标签可以嵌套组件。

例如：

```jsx
<Link to="/" className="navbar-brand">
  {appName.toLowerCase()}
</Link>
```

这里 `{appName.toLowerCase()}` 会执行 JavaScript 表达式，并把结果渲染到页面。

## 3. 组件拆分

`Header.js` 里拆了三个组件：

```js
function LoggedOutNavbar() {}
function LoggedInNavbar() {}
function Header() {}
```

这样拆分的原因是：登录前和登录后的导航栏不同。

`Header` 里通过条件渲染决定显示哪个组件：

```jsx
{
  isAuthenticated ? <LoggedInNavbar /> : <LoggedOutNavbar />;
}
```

含义：

```text
如果已登录，显示 LoggedInNavbar
否则，显示 LoggedOutNavbar
```

组件拆分的目的不是为了把文件变多，而是为了让不同职责的 UI 分开维护。

## 4. props

`ArticlePreview` 接收一个 `article`：

```js
function ArticlePreview({ article }) {
  ...
}
```

这里的 `article` 就是 props。

props 是父组件传给子组件的数据。

例如父组件可以这样使用：

```jsx
<ArticlePreview article={someArticle} />
```

子组件通过参数拿到：

```js
function ArticlePreview({ article }) {
```

然后渲染：

```jsx
<h1>{article.title}</h1>
<p>{article.description}</p>
<TagsList tags={article.tagList} />
```

核心关系：

```text
父组件负责传数据
子组件负责根据数据渲染 UI
```

## 5. 组件嵌套

`Home/index.js` 里：

```jsx
<div className="home-page">
  <Banner />

  <div className="container page">
    <div className="row">
      <MainView />

      <div className="col-md-3">
        <TagsSidebar />
      </div>
    </div>
  </div>
</div>
```

`Home` 本身是页面组件，但它不是把所有内容都写在一个函数里，而是组合了多个子组件：

```text
Home
  -> Banner
  -> MainView
  -> TagsSidebar
```

这是 React 的核心开发方式：用小组件组合成大页面。

## 6. 事件处理

`ArticlePreview` 里有收藏按钮：

```jsx
<button className={favoriteButtonClass} onClick={handleClick}>
  <i className="ion-heart" /> {article.favoritesCount}
</button>
```

`onClick={handleClick}` 表示点击按钮时执行 `handleClick`。

事件函数：

```js
const handleClick = (event) => {
  event.preventDefault();

  if (article.favorited) {
    dispatch(unfavoriteArticle(article.slug));
  } else {
    dispatch(favoriteArticle(article.slug));
  }
};
```

这里的 React 重点是：

- 事件通过 `onClick` 绑定。
- 事件处理函数接收 `event`。
- `event.preventDefault()` 用来阻止默认行为。

在这个组件里，按钮外层区域有文章详情链接，点击收藏按钮时不希望跳转，所以调用了 `preventDefault()`。

## 7. `return null`

`Banner.js` 里：

```js
if (isAuthenticated) {
  return null;
}
```

意思是：如果用户已登录，这个组件什么都不显示。

在 React 中：

```text
return null = 这个组件不渲染任何 DOM
```

这是合法且常见的写法。

## 8. `memo`

很多组件最后这样导出：

```js
export default memo(Header);
```

`memo` 是 React 的性能优化工具。

简单理解：

```text
如果组件输入没有变化，就尽量不要重复渲染
```

初学阶段不用过早纠结 `memo` 的细节。先知道它是给组件包了一层渲染优化即可。

## 9. 本节重点

React 组件基础先记住这几件事：

```text
1. 组件是返回 UI 的函数。
2. JSX 是在 JavaScript 里写页面结构。
3. props 是父组件传给子组件的数据。
4. 组件可以拆分，也可以嵌套。
5. 事件通过 onClick、onChange 等属性绑定。
6. return null 表示这个组件不显示任何内容。
```

下一部分会进入 React 状态和事件，重点看 `useState`、表单输入、事件处理和表单提交。
