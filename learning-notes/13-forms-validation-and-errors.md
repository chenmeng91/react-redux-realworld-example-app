# 13. 表单、校验和错误展示

这一部分对应 `LEARNING.md` 里的“表单、校验和错误展示”，主要总结登录/注册表单、文章编辑表单、评论表单，以及错误如何从接口进入 Redux state，最后通过 `ListErrors` 展示出来。

主要参考文件：

- `src/features/auth/AuthScreen.js`
- `src/components/Editor.js`
- `src/features/comments/CommentSection.js`
- `src/components/ListErrors.js`
- `src/features/auth/authSlice.js`
- `src/reducers/article.js`
- `src/features/comments/commentsSlice.js`
- `src/common/utils.js`
- `src/agent.js`

## 1. 表单输入的基本模式

这个项目里的表单基本都使用 React 受控组件。

以登录页为例：

```js
const [username, setUsername] = useState('');
const [password, setPassword] = useState('');
const [email, setEmail] = useState('');
```

输入框：

```jsx
<input type="email" value={email} onChange={changeEmail} />
```

事件函数：

```js
const changeEmail = (event) => {
  setEmail(event.target.value);
};
```

流程：

```text
用户输入
  -> input 触发 onChange
  -> setEmail 更新 React state
  -> 组件重新渲染
  -> input value 显示最新值
```

这种模式叫受控组件：

```text
输入框显示什么，由 React state 决定
输入框变化时，再通过 onChange 更新 React state
```

## 2. 登录和注册表单

`AuthScreen` 同时负责登录和注册。

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

`isRegisterScreen` 决定当前是注册页还是登录页。

提交逻辑：

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
提交表单
  -> event.preventDefault() 阻止浏览器默认刷新
  -> 根据 isRegisterScreen 选择 register 或 login
  -> dispatch 异步 thunk
  -> 成功后跳转
  -> 失败后不跳转，显示错误
```

## 3. 当前项目的前端校验比较少

这个 demo 基本依赖后端校验，没有在提交前完整检查：

```text
email 是否为空
email 格式是否合法
password 是否为空
username 是否为空
文章 title/body 是否为空
```

真实项目通常会有两层校验：

```text
前端基础校验：
  必填
  email 格式
  password 长度
  tag 去重
  title/body 必填

后端权威校验：
  email 是否已注册
  密码是否正确
  username 是否占用
  文章数据是否合法
```

前端校验不能替代后端校验。它主要用于更快给用户反馈，减少无效请求。

当前 demo 更适合作为学习异步错误流转的例子：

```text
提交表单
  -> 请求接口
  -> 后端返回错误
  -> rejected action
  -> Redux 保存 errors
  -> ListErrors 展示
```

## 4. loading 状态如何禁用表单

登录页读取 loading 状态：

```js
const inProgress = useSelector(selectIsLoading);
```

表单中：

```jsx
<fieldset disabled={inProgress}>
```

`selectIsLoading`：

```js
export const selectIsLoading = (state) =>
  selectAuthSlice(state).status === Status.LOADING;
```

`authSlice` 中 pending 时：

```js
builder.addMatcher(
  (action) => /auth\/.*\/pending/.test(action.type),
  loadingReducer
);
```

`loadingReducer`：

```js
export function loadingReducer(state) {
  state.status = Status.LOADING;
}
```

所以流程是：

```text
dispatch(login/register)
  -> auth/.../pending
  -> state.auth.status = loading
  -> selectIsLoading 返回 true
  -> fieldset disabled
  -> 表单被禁用，避免重复提交
```

## 5. 错误如何从接口抛出

统一请求封装在 `src/agent.js`：

```js
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
```

如果响应不是 2xx：

```js
if (!response.ok) throw result;
```

后端错误通常长这样：

```js
{
  errors: {
    email: ["can't be blank"],
    password: ["can't be blank"]
  }
}
```

这个错误会被 thunk 的 `catch` 捕获。

## 6. auth 错误如何进入 Redux

登录 thunk：

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
  }
);
```

`isApiError`：

```js
export function isApiError(error) {
  return typeof error === 'object' && error !== null && 'errors' in error;
}
```

如果是接口错误：

```js
return thunkApi.rejectWithValue(error);
```

这样 rejected action 的错误会放在：

```js
action.payload;
```

`authSlice` 中：

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

所以登录失败后：

```js
state.auth.errors = action.payload.errors;
```

然后页面读取：

```js
const errors = useSelector(selectErrors);
```

渲染：

```jsx
<ListErrors errors={errors} />
```

## 7. ListErrors 如何展示错误

`src/components/ListErrors.js`：

```js
function ListErrors({ errors }) {
  if (!errors || Object.keys(errors).length === 0) {
    return null;
  }

  const errorMessages = Object.entries(errors).flatMap(([property, messages]) =>
    messages.map((message) => `${property} ${message}`)
  );

  return (
    <ul className="error-messages">
      {errorMessages.map((message) => (
        <li key={message}>{message}</li>
      ))}
    </ul>
  );
}
```

传入：

```js
{
  email: ["can't be blank"],
  password: ["can't be blank"]
}
```

会转成：

```js
["email can't be blank", "password can't be blank"];
```

最后渲染为：

```html
<ul class="error-messages">
  <li>email can't be blank</li>
  <li>password can't be blank</li>
</ul>
```

如果没有错误：

```js
return null;
```

页面上不显示任何内容。

## 8. 文章编辑表单

文章编辑页在 `src/components/Editor.js`。

它既支持创建文章，也支持编辑文章。

通过 URL 是否有 `slug` 判断：

```js
const { slug } = useParams();
```

```text
/editor
  -> 创建文章

/editor/:slug
  -> 编辑已有文章
```

表单状态：

```js
const [title, setTitle] = useState('');
const [description, setDescription] = useState('');
const [body, setBody] = useState('');
const [tagInput, setTagInput] = useState('');
const [tagList, setTagList] = useState([]);
```

提交：

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

有 `slug`：

```text
updateArticle(article)
```

没有 `slug`：

```text
createArticle(article)
```

这个 demo 里有个明显不足：

```js
navigate('/');
```

它没有等创建或更新成功就跳转了。

更严谨的写法应该等 action 结果：

```js
dispatch(slug ? updateArticle(article) : createArticle(article)).then(
  (action) => {
    if (action.meta.requestStatus === 'rejected') {
      return;
    }

    navigate('/');
  }
);
```

或者使用 `.unwrap()`。

## 9. 编辑文章时如何回填表单

`Editor` 中：

```js
const reset = () => {
  if (slug && article) {
    setTitle(article.title);
    setDescription(article.description);
    setBody(article.body);
    setTagList(article.tagList);
  } else {
    setTitle('');
    setDescription('');
    setBody('');
    setTagInput('');
    setTagList([]);
  }
};
```

加载文章：

```js
useEffect(() => {
  reset();
  if (slug) {
    dispatch(getArticle(slug));
  }
}, [slug]);
```

文章回来后同步表单：

```js
useEffect(reset, [article]);
```

流程：

```text
进入 /editor/article-slug
  -> slug 有值
  -> dispatch(getArticle(slug))
  -> 文章详情进入 Redux
  -> article 变化
  -> useEffect(reset, [article])
  -> setTitle/setDescription/setBody/setTagList
  -> 表单回填
```

## 10. tag 输入如何处理

文章 tag 不是单个字符串，而是数组。

```js
const [tagInput, setTagInput] = useState('');
const [tagList, setTagList] = useState([]);
```

按 Enter 添加 tag：

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

逻辑：

```text
按 Enter
  -> 阻止默认行为
  -> tagInput 不为空
  -> tagList 中还没有这个 tag
  -> 加入 tagList
  -> 清空 tagInput
```

删除 tag：

```js
const removeTag = (tag) => () => {
  setTagList(tagList.filter((_tag) => _tag !== tag));
};
```

这里体现了一个常见表单模式：

```text
tagInput：
  当前输入框的临时值

tagList：
  最终提交的数据
```

## 11. 文章错误如何展示

`src/reducers/article.js` 中：

```js
export const createArticle = createAsyncThunk(
  'article/createArticle',
  agent.Articles.create,
  { serializeError }
);

export const updateArticle = createAsyncThunk(
  'article/updateArticle',
  agent.Articles.update,
  { serializeError }
);
```

失败时：

```js
builder.addCase(createArticle.rejected, (state, action) => {
  state.errors = action.error.errors;
  state.inProgress = false;
});

builder.addCase(updateArticle.rejected, (state, action) => {
  state.errors = action.error.errors;
  state.inProgress = false;
});
```

`Editor` 中：

```js
const { article, errors, inProgress } = useSelector((state) => state.article);
```

渲染：

```jsx
<ListErrors errors={errors} />
```

这里和 auth 的错误处理方式不一样：

```text
auth：
  使用 rejectWithValue
  错误在 action.payload.errors

article：
  使用 serializeError
  错误在 action.error.errors
```

这是这个 demo 里写法不统一的地方。

## 12. 评论表单错误

评论提交在 `CommentForm`：

```js
dispatch(createComment({ articleSlug: slug, comment: { body } }));
```

失败时：

```js
.addCase(createComment.rejected, (state, action) => {
  state.status = Status.FAILURE;
  state.errors = action.payload?.errors;
  commentAdapter.removeOne(state, action.meta.requestId);
});
```

`CommentSection` 中：

```js
const errors = useSelector(selectErrors);

<ListErrors errors={errors} />;
```

所以评论错误链路是：

```text
提交评论
  -> createComment pending 乐观插入临时评论
  -> 请求失败
  -> action.payload?.errors
  -> state.comments.errors
  -> 删除临时评论
  -> ListErrors 展示错误
```

## 13. 三条错误链路对比

登录失败：

```text
用户提交登录表单
  -> dispatch(login({ email, password }))
  -> agent 请求 /users/login
  -> 后端返回错误
  -> agent throw result
  -> login catch error
  -> thunkApi.rejectWithValue(error)
  -> auth/login/rejected
  -> failureReducer: state.auth.errors = action.payload.errors
  -> AuthScreen useSelector(selectErrors)
  -> ListErrors 渲染错误
```

文章发布失败：

```text
用户提交文章表单
  -> dispatch(createArticle(article))
  -> agent 请求 /articles
  -> 后端返回错误
  -> article/createArticle/rejected
  -> article reducer: state.article.errors = action.error.errors
  -> Editor useSelector(state.article.errors)
  -> ListErrors 渲染错误
```

评论失败：

```text
用户提交评论
  -> dispatch(createComment({ articleSlug, comment }))
  -> pending 乐观插入临时评论
  -> agent 请求 /articles/:slug/comments
  -> 后端返回错误
  -> comments/createComment/rejected
  -> state.comments.errors = action.payload?.errors
  -> 删除临时评论
  -> CommentSection useSelector(selectErrors)
  -> ListErrors 渲染错误
```

## 14. 表单功能的通用模式

这个项目的表单可以总结成：

```text
输入框 value 绑定 useState
onChange 更新 useState
onSubmit 阻止默认浏览器行为
dispatch async thunk
pending 设置 loading
loading 禁用按钮或表单
rejected 把 errors 写入 Redux
ListErrors 统一展示 errors
fulfilled 清理 errors 或跳转
```

## 15. 这个 demo 的不足

这一节也能看到一些真实项目里应该改进的点：

```text
前端基础校验较少，主要依赖后端校验
Editor 提交后没有等待成功就 navigate('/')
auth/article/comments 的错误处理方式不完全统一
部分 loading 状态处理比较粗糙
表单逻辑分散，没有统一表单抽象或表单库
```

学习时要区分：

```text
这个项目展示了表单、异步请求、错误展示的基本链路
但并不是生产级表单处理的完整范式
```
