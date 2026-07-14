# 04. React 状态和事件

这一部分对应 `LEARNING.md` 里的“React 状态和事件”，主要参考这些文件：

- `src/features/auth/AuthScreen.js`
- `src/components/Editor.js`
- `src/components/ListErrors.js`

核心内容：

- `useState`
- 输入框绑定
- `onChange`
- `onSubmit` / `onClick`
- `event.preventDefault()`
- 表单提交
- `fieldset`

## 1. 什么是 React 状态

React 状态就是组件自己记住的数据。

登录页里有三个输入框：

```js
const [username, setUsername] = useState('');
const [password, setPassword] = useState('');
const [email, setEmail] = useState('');
```

这表示组件内部有三个状态：

```text
username 当前用户名
password 当前密码
email 当前邮箱
```

`useState('')` 里的 `''` 是初始值。

每一组状态都长这样：

```js
const [value, setValue] = useState(initialValue);
```

例如：

```js
const [email, setEmail] = useState('');
```

含义：

```text
email 是当前值
setEmail 是修改 email 的函数
初始值是空字符串
```

## 2. 输入框如何绑定状态

登录页的 email 输入框：

```jsx
<input type="email" placeholder="Email" value={email} onChange={changeEmail} />
```

两个关键点：

```jsx
value = { email };
```

表示输入框显示的值来自 React 状态 `email`。

```jsx
onChange = { changeEmail };
```

表示用户输入时，执行 `changeEmail`。

事件函数：

```js
const changeEmail = (event) => {
  setEmail(event.target.value);
};
```

`event.target.value` 就是输入框当前输入的内容。

完整链路：

```text
用户输入
  -> 触发 onChange
  -> changeEmail 拿到 event.target.value
  -> setEmail 更新 React 状态
  -> React 重新渲染
  -> input 的 value 显示新 email
```

这种写法叫受控组件：

```text
输入框的值由 React state 控制
```

## 3. 为什么要写 `value + onChange`

如果只写：

```jsx
<input />
```

输入框自己也能输入，但 React 不知道里面是什么。

如果写成：

```jsx
<input value={email} onChange={changeEmail} />
```

React 就能随时知道当前输入内容。

这样提交表单时可以直接使用：

```js
login({ email, password });
```

不需要再从 DOM 里手动取值。

## 4. 表单提交

登录页里：

```jsx
<form onSubmit={authenticateUser}>
```

点击 submit 按钮时，会触发：

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

React 单页应用不希望表单提交导致页面刷新，所以要写：

```js
event.preventDefault();
```

然后根据当前页面是注册还是登录，决定调用：

```js
register({ username, email, password });
```

或者：

```js
login({ email, password });
```

提交成功后用 `navigate` 跳转页面。

## 5. `fieldset` 的作用

`fieldset` 是 HTML 表单里的语义标签，用来把一组表单控件分组。

常见写法：

```html
<fieldset>
  <input />
  <input />
  <button />
</fieldset>
```

它还可以配合 `legend` 使用：

```html
<fieldset>
  <legend>Login Info</legend>
  <input type="email" />
  <input type="password" />
</fieldset>
```

在这个项目里，最重要的是：

```jsx
<fieldset disabled={inProgress}>
```

含义：

```text
如果 inProgress 为 true
整个 fieldset 里的 input、button 都会被禁用
```

也就是说，请求登录或注册中时，用户不能继续输入，也不能重复点击提交按钮。

它比给每个 input、button 都写 `disabled={inProgress}` 更简洁。

这个项目里的模式是：

```text
form 负责提交
fieldset 负责批量管理表单控件状态
```

另外还有：

```jsx
<fieldset className="form-group">
```

这些主要是为了套 CSS 样式，把每个输入项作为一个表单组来布局。

## 6. 按钮和表单禁用状态

登录页里：

```jsx
<fieldset disabled={inProgress}>
```

`inProgress` 来自 Redux：

```js
const inProgress = useSelector(selectIsLoading);
```

常见模式：

```text
请求中 -> 禁用表单
请求结束 -> 恢复表单
```

这样可以避免重复提交。

## 7. Editor 里的多个状态

文章编辑页管理了更多状态：

```js
const [title, setTitle] = useState('');
const [description, setDescription] = useState('');
const [body, setBody] = useState('');
const [tagInput, setTagInput] = useState('');
const [tagList, setTagList] = useState([]);
```

分别表示：

```text
title 文章标题
description 文章描述
body 文章正文
tagInput 当前正在输入的标签
tagList 已添加的标签数组
```

每个输入框都对应一组 `value + onChange`。

例如标题：

```jsx
<input placeholder="Article Title" value={title} onChange={changeTitle} />
```

```js
const changeTitle = (event) => {
  setTitle(event.target.value);
};
```

## 8. 数组状态怎么更新

标签列表是数组：

```js
const [tagList, setTagList] = useState([]);
```

添加标签：

```js
if (tagInput && !tagList.includes(tagInput)) setTagList([...tagList, tagInput]);
```

这里没有直接写：

```js
tagList.push(tagInput);
```

因为 React 状态不要直接修改原数组。

正确做法是创建一个新数组：

```js
[...tagList, tagInput];
```

意思是：

```text
复制旧 tagList，再追加一个 tagInput
```

删除标签：

```js
setTagList(tagList.filter((_tag) => _tag !== tag));
```

`filter` 也会返回一个新数组。

关键原则：

```text
React state 更新时，尽量创建新对象/新数组，不要直接改旧对象/旧数组
```

## 9. 键盘事件

Editor 里标签输入框：

```jsx
<input value={tagInput} onChange={changeTagInput} onKeyUp={addTag} />
```

`onKeyUp` 是键盘松开时触发。

```js
const addTag = (event) => {
  if (event.key === 'Enter') {
    event.preventDefault();

    if (tagInput && !tagList.includes(tagInput))
      setTagList([...tagList, tagInput]);

    setTagInput('');
  }
};
```

意思是：

```text
如果按下 Enter
  -> 阻止默认行为
  -> 如果 tagInput 不为空且没有重复
  -> 添加到 tagList
  -> 清空 tagInput
```

## 10. 事件函数可以返回函数

删除标签这里：

```js
const removeTag = (tag) => () => {
  setTagList(tagList.filter((_tag) => _tag !== tag));
};
```

使用时：

```jsx
<i className="ion-close-round" onClick={removeTag(tag)} />
```

`onClick` 需要的是一个函数。

`removeTag(tag)` 执行后返回：

```js
() => {
  setTagList(...)
}
```

所以最终传给 `onClick` 的仍然是一个事件处理函数。

可以拆开理解：

```js
const handleRemove = removeTag(tag);
onClick = { handleRemove };
```

## 11. 提交文章

Editor 里提交按钮：

```jsx
<button type="button" disabled={inProgress} onClick={submitForm}>
  Publish Article
</button>
```

点击后：

```js
const submitForm = (event) => {
  event.preventDefault();

  const article = {
    slug,
    title,
    description,
    body,
    tagList,
  };

  dispatch(slug ? updateArticle(article) : createArticle(article));
  navigate('/');
};
```

这里把多个 state 组合成一个对象：

```js
const article = {
  slug,
  title,
  description,
  body,
  tagList,
};
```

然后根据有没有 `slug` 判断：

```text
有 slug -> 更新文章
没有 slug -> 创建文章
```

## 12. 本节重点

React 状态和事件先记住这些：

```text
1. useState 让组件拥有自己的状态。
2. input 的 value 绑定 state。
3. input 的 onChange 更新 state。
4. value + onChange 叫受控组件。
5. 表单提交时通常要 event.preventDefault()。
6. fieldset 可以分组表单，也可以一次性禁用一组控件。
7. 数组/对象状态更新时，不要直接修改旧值，要创建新值。
8. 事件处理函数通过 onClick、onChange、onSubmit、onKeyUp 绑定。
```

本节核心模型：

```text
用户操作
  -> 触发事件
  -> setState 更新状态
  -> React 重新渲染 UI
```
