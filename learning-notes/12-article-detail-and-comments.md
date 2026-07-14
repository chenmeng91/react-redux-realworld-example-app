# 12. 文章详情和评论

这一部分对应 `LEARNING.md` 里的“文章详情和评论”，同时融合关于 `useEffect cleanup`、`articleSlice.actions`、`Suspense`、`createAsyncThunk` 短写法和长写法差异、`createEntityAdapter`、`ids/entities` 结构等追问。

主要参考文件：

- `src/components/Article/index.js`
- `src/components/Article/ArticleMeta.js`
- `src/components/Article/ArticleActions.js`
- `src/reducers/article.js`
- `src/features/comments/CommentSection.js`
- `src/features/comments/CommentList.js`
- `src/features/comments/commentsSlice.js`
- `src/agent.js`

## 1. 文章详情页入口

文章详情页由路由进入。

`src/components/App.js` 中有：

```jsx
<Route path="/article/:slug" element={<Article />} />
```

所以访问：

```text
/article/my-first-post
```

会渲染：

```jsx
<Article />
```

其中：

```text
my-first-post
```

就是动态路由参数 `slug`。

在 `src/components/Article/index.js` 中：

```js
const { slug } = useParams();
```

`useParams()` 会从当前 URL 中取出：

```js
{
  slug: 'my-first-post';
}
```

## 2. Article 组件加载文章详情

`src/components/Article/index.js`：

```js
function Article({ match }) {
  const dispatch = useDispatch();
  const article = useSelector((state) => state.article.article);
  const inProgress = useSelector((state) => state.article.inProgress);
  const { slug } = useParams();
  const renderMarkdown = () => ({ __html: xss(snarkdown(article.body)) });

  useEffect(() => {
    const fetchArticle = dispatch(getArticle(slug));
    return () => {
      fetchArticle.abort();
    };
  }, [match]);

  useEffect(() => () => dispatch(articlePageUnloaded()), []);
}
```

核心流程：

```text
Article 组件渲染
  -> useParams 取 URL 里的 slug
  -> dispatch(getArticle(slug))
  -> 请求文章详情
  -> Redux 保存文章
  -> Article 重新渲染文章内容
```

第一个 `useEffect` 负责请求文章：

```js
useEffect(() => {
  const fetchArticle = dispatch(getArticle(slug));
  return () => {
    fetchArticle.abort();
  };
}, [match]);
```

`dispatch(getArticle(slug))` 返回的是 `createAsyncThunk` 的 promise-like 对象，带 `.abort()`。

组件卸载或 effect 重新执行前，会执行 cleanup：

```js
fetchArticle.abort();
```

用来中止未完成的文章详情请求。

## 3. 离开文章页时为什么清空 state

这句代码：

```js
useEffect(() => () => dispatch(articlePageUnloaded()), []);
```

可以展开成：

```js
useEffect(() => {
  return () => {
    dispatch(articlePageUnloaded());
  };
}, []);
```

`useEffect` 返回的函数叫 cleanup 函数。

当 `Article` 组件卸载时，React 会执行这个 cleanup。

什么时候卸载？

```text
从 /article/abc 跳到 /
从 /article/abc 跳到 /login
React Router 不再渲染 <Article />
```

这时会执行：

```js
dispatch(articlePageUnloaded());
```

`src/reducers/article.js` 中：

```js
reducers: {
  articlePageUnloaded: () => initialState,
},
```

所以它会把 `article` slice 重置为：

```js
const initialState = {
  article: undefined,
  inProgress: false,
  errors: undefined,
};
```

作用是避免旧文章闪现。

如果不清空，可能出现：

```text
打开 /article/a
  -> state.article.article = A

离开文章页
  -> state 里仍然保留 A

打开 /article/b
  -> B 请求还没返回前
  -> 页面可能先显示旧文章 A
  -> B 返回后才变成 B
```

所以离开详情页时清空 state，是为了避免下一次进入文章页时先显示旧数据。

## 4. articlePageUnloaded 是怎么生成的

`src/reducers/article.js` 中：

```js
const articleSlice = createSlice({
  name: 'article',
  initialState,
  reducers: {
    articlePageUnloaded: () => initialState,
  },
  extraReducers: ...
});
```

Redux Toolkit 会根据 `reducers` 自动生成 action creator。

所以：

```js
export const { articlePageUnloaded } = articleSlice.actions;
```

等价于：

```js
const articlePageUnloaded = articleSlice.actions.articlePageUnloaded;

export { articlePageUnloaded };
```

`articlePageUnloaded` 是一个函数。

调用：

```js
articlePageUnloaded();
```

大概返回：

```js
{
  type: 'article/articlePageUnloaded',
  payload: undefined
}
```

type 的来源是：

```text
slice name: article
reducer name: articlePageUnloaded
拼成: article/articlePageUnloaded
```

所以：

```js
dispatch(articlePageUnloaded());
```

会触发对应 case reducer：

```js
articlePageUnloaded: () => initialState;
```

从而重置文章详情 state。

## 5. getArticle 的短写法

`src/reducers/article.js` 中：

```js
export const getArticle = createAsyncThunk(
  'article/getArticle',
  agent.Articles.get
);
```

`createAsyncThunk` 的基本形式是：

```js
createAsyncThunk(typePrefix, payloadCreator, options);
```

这里第二个参数直接传了：

```js
agent.Articles.get;
```

因为 `agent.Articles.get` 本身就是一个函数：

```js
get: (slug) => requests.get(`/articles/${slug}`);
```

所以：

```js
dispatch(getArticle(slug));
```

等价于让 `createAsyncThunk` 内部执行：

```js
agent.Articles.get(slug);
```

如果写完整一点，也可以写成：

```js
export const getArticle = createAsyncThunk(
  'article/getArticle',
  async (slug) => {
    return await agent.Articles.get(slug);
  }
);
```

短写法能成立的原因：

```text
参数刚好匹配：getArticle(slug) -> agent.Articles.get(slug)
返回值也刚好适合直接作为 payload：{ article: ... }
不需要 condition 或额外加工
```

## 6. getArticle 成功后如何保存文章

`src/reducers/article.js`：

```js
builder.addCase(getArticle.fulfilled, (state, action) => {
  state.article = action.payload.article;
  state.inProgress = false;
});
```

后端返回大概是：

```js
{
  article: {
    slug: 'my-first-post',
    title: '...',
    body: '...',
    tagList: [...],
    author: {...}
  }
}
```

`createAsyncThunk` 把接口返回值放进：

```js
action.payload;
```

所以：

```js
action.payload.article;
```

就是接口返回的文章对象。

然后保存到：

```js
state.article.article;
```

这里两个 `article` 含义不同：

```text
第一个 article：
  Redux root state 里的 slice 名

第二个 article：
  article slice 内部的字段
```

所以：

```js
useSelector((state) => state.article.article);
```

意思是：

```text
从 root state 中取 article slice
再取这个 slice 里的 article 字段
```

## 7. 文章 loading 状态

`src/reducers/article.js`：

```js
builder.addMatcher(
  (action) => action.type.endsWith('/pending'),
  (state) => {
    state.inProgress = true;
  }
);
```

只要 action type 以 `/pending` 结尾，就会：

```js
state.inProgress = true;
```

文章还没加载出来时：

```js
if (!article) {
  return (
    ...
    {inProgress && <h1 role="alert">Article is loading</h1>}
    ...
  );
}
```

所以：

```text
article 还不存在
inProgress 为 true
  -> 显示 Article is loading
```

这里有个细节：当前 matcher 写得比较宽：

```js
action.type.endsWith('/pending');
```

它会匹配所有 pending action，不只匹配 article 模块。

更严谨的写法通常会限制范围：

```js
action.type.startsWith('article/') && action.type.endsWith('/pending');
```

## 8. Markdown 如何渲染

文章正文是 Markdown。

`Article/index.js` 中：

```js
const renderMarkdown = () => ({ __html: xss(snarkdown(article.body)) });
```

渲染：

```jsx
<article dangerouslySetInnerHTML={renderMarkdown()} />
```

这里有三步：

```text
article.body：
  后端返回的 Markdown 文本

snarkdown(article.body)：
  把 Markdown 转成 HTML

xss(...)：
  过滤危险 HTML，降低 XSS 风险

dangerouslySetInnerHTML：
  让 React 把字符串作为 HTML 插入页面
```

`dangerouslySetInnerHTML` 之所以名字里有 dangerous，是因为直接插入 HTML 有 XSS 风险。

所以这里先用：

```js
xss(...)
```

做过滤。

## 9. ArticleMeta 和作者操作

`src/components/Article/ArticleMeta.js`：

```js
function ArticleMeta() {
  const currentUser = useSelector(selectUser);
  const article = useSelector((state) => state.article.article);
  const isAuthor = currentUser?.username === article?.author.username;

  if (!article) return null;

  return (
    ...
    {isAuthor ? <ArticleActions /> : null}
  );
}
```

逻辑：

```text
读取当前登录用户
读取当前文章
比较 currentUser.username 和 article.author.username
如果相等，说明当前用户是作者
显示编辑/删除按钮
```

`ArticleActions`：

```js
<Link to={`/editor/${slug}`} className="btn btn-outline-secondary btn-sm">
  <i className="ion-edit"></i> Edit Article
</Link>
```

编辑进入：

```text
/editor/:slug
```

删除：

```js
const removeArticle = () => {
  dispatch(deleteArticle(slug));
  navigate('/');
};
```

点击删除后 dispatch 删除文章，并跳回首页。

## 10. Suspense 的作用

文章详情里评论区是懒加载的：

```js
const CommentSection = lazy(() =>
  import('../../features/comments/CommentSection')
);
```

渲染时：

```jsx
<Suspense fallback={<p>Loading comments</p>}>
  <CommentSection />
</Suspense>
```

`lazy` 表示：

```text
CommentSection 组件代码不要一开始就打进主包
等真正渲染到这里时，再异步加载对应 JS chunk
```

`Suspense` 表示：

```text
如果 CommentSection 的组件代码还没加载完成
先显示 fallback
```

所以这段的行为是：

```text
文章标题、作者、正文、tag 正常显示
评论区组件代码还没加载完时，评论区显示 Loading comments
组件代码加载完后，渲染 CommentSection
```

`Suspense fallback` 只替换它包住的区域。

当前代码只包住：

```jsx
<CommentSection />
```

所以不会让整个文章详情页都变成 `Loading comments`。

还要区分两种 loading：

```text
Suspense fallback：
  评论区组件代码还没加载完

CommentList 的 isLoading：
  评论接口请求还没返回
```

`Suspense` 本身不负责 Redux 请求状态，它主要负责懒加载组件还没 ready 时显示占位 UI。

## 11. CommentSection 根据登录态显示内容

`src/features/comments/CommentSection.js`：

```js
function CommentSection() {
  const isAuthenticaded = useSelector(selectIsAuthenticated);
  const errors = useSelector(selectErrors);

  return (
    <div className="row">
      {isAuthenticaded ? (
        <div className="col-xs-12 col-md-8 offset-md-2">
          <ListErrors errors={errors} />

          <CommentForm />

          <CommentList />
        </div>
      ) : (
        <div className="col-xs-12 col-md-8 offset-md-2">
          <p>
            <Link to="/login">Sign in</Link>
            &nbsp;or&nbsp;
            <Link to="/register">sign up</Link>
            &nbsp;to add comments on this article.
          </p>

          <CommentList />
        </div>
      )}
    </div>
  );
}
```

逻辑：

```text
已登录：
  显示评论错误
  显示评论输入框
  显示评论列表

未登录：
  提示登录或注册
  仍然显示评论列表
```

所以：

```text
评论列表所有人可见
发表评论需要登录
```

## 12. CommentList 加载评论

`src/features/comments/CommentList.js`：

```js
function CommentList() {
  const dispatch = useDispatch();
  const comments = useSelector(selectAllComments);
  const isLoading = useSelector(selectIsLoading);
  const { slug } = useParams();

  useEffect(() => {
    const fetchComments = dispatch(getCommentsForArticle(slug));

    return () => {
      fetchComments.abort();
    };
  }, [slug]);

  if (isLoading) {
    return <p>Loading comments</p>;
  }

  return (
    <>
      {comments.map((comment) => (
        <Comment key={comment.id} comment={comment} />
      ))}
    </>
  );
}
```

流程：

```text
CommentList mount
  -> useParams 取 slug
  -> dispatch(getCommentsForArticle(slug))
  -> 请求 /articles/:slug/comments
  -> comments slice 保存评论
  -> selectAllComments 读出评论数组
  -> map 渲染每条评论
```

组件卸载或 slug 变化时：

```js
fetchComments.abort();
```

中止未完成的评论请求。

## 13. getCommentsForArticle 为什么写法更长

评论请求：

```js
export const getCommentsForArticle = createAsyncThunk(
  'comments/getCommentsForArticle',
  async (articleSlug) => {
    const { comments } = await agent.Comments.forArticle(articleSlug);

    return comments;
  },
  {
    condition: (_, { getState }) => !selectIsLoading(getState()),
  }
);
```

它比 `getArticle` 写得长，原因有两个。

第一，它加工了接口返回值。

`agent.Comments.forArticle(articleSlug)` 返回：

```js
{
  comments: [...]
}
```

但这个 thunk 希望 `action.payload` 直接是评论数组：

```js
comments;
```

所以写：

```js
const { comments } = await agent.Comments.forArticle(articleSlug);
return comments;
```

这样 reducer 里可以直接：

```js
commentAdapter.setAll(state, action.payload);
```

如果写成短写法：

```js
export const getCommentsForArticle = createAsyncThunk(
  'comments/getCommentsForArticle',
  agent.Comments.forArticle
);
```

那 `action.payload` 会是：

```js
{
  comments: [...]
}
```

reducer 就要写：

```js
commentAdapter.setAll(state, action.payload.comments);
```

第二，它多了 `condition`：

```js
condition: (_, { getState }) => !selectIsLoading(getState());
```

意思是：

```text
如果评论当前正在 loading，就不要重复请求
```

所以：

```text
getArticle：
  参数和返回值刚好匹配，不需要额外配置，所以可以短写

getCommentsForArticle：
  需要把 { comments } 加工成 comments 数组
  需要 condition 防重复请求
  所以写成 async 函数 + options
```

## 14. 评论接口

`src/agent.js`：

```js
const Comments = {
  create: (slug, comment) =>
    requests.post(`/articles/${slug}/comments`, { comment }),

  delete: (slug, commentId) =>
    requests.del(`/articles/${slug}/comments/${commentId}`),

  forArticle: (slug) => requests.get(`/articles/${slug}/comments`),
};
```

对应接口：

```text
GET /articles/:slug/comments
POST /articles/:slug/comments
DELETE /articles/:slug/comments/:commentId
```

## 15. createEntityAdapter 是什么

`src/features/comments/commentsSlice.js`：

```js
const commentAdapter = createEntityAdapter({
  sortComparer: (a, b) => b.createdAt.localeCompare(a.createdAt),
});
```

`createEntityAdapter` 会创建一套管理“实体列表”的工具函数：

```text
commentAdapter.getInitialState
commentAdapter.setAll
commentAdapter.addOne
commentAdapter.updateOne
commentAdapter.removeOne
commentAdapter.getSelectors
```

这里的实体就是评论 comment。

一条评论大概长这样：

```js
{
  id: 123,
  body: 'hello',
  author: {...},
  createdAt: '2024-01-01T00:00:00.000Z',
  updatedAt: '2024-01-01T00:00:00.000Z'
}
```

`sortComparer` 是排序规则：

```js
sortComparer: (a, b) => b.createdAt.localeCompare(a.createdAt);
```

意思是：

```text
按照 createdAt 倒序排序
新的评论排前面
```

## 16. ids/entities 结构是不是业务相关

初始化：

```js
const initialState = commentAdapter.getInitialState({
  status: Status.IDLE,
});
```

`commentAdapter.getInitialState()` 默认生成：

```js
{
  ids: [],
  entities: {}
}
```

传入：

```js
{
  status: Status.IDLE;
}
```

后会合并成：

```js
{
  ids: [],
  entities: {},
  status: 'idle'
}
```

所以：

```js
state.comments = {
  ids: [],
  entities: {},
  status: 'idle',
};
```

这个结构来自 `createEntityAdapter`，不是评论业务特有的。

`ids/entities` 是一种通用 normalized entity 存储结构，用来管理“一组有 id 的对象”。

比如评论：

```js
{
  ids: [1, 2],
  entities: {
    1: { id: 1, body: 'hello' },
    2: { id: 2, body: 'world' }
  }
}
```

文章也可以：

```js
{
  ids: ['article-a', 'article-b'],
  entities: {
    'article-a': { slug: 'article-a', title: 'A' },
    'article-b': { slug: 'article-b', title: 'B' }
  }
}
```

其中：

```text
ids：
  保存顺序

entities：
  按 id 快速查找对象
```

业务相关的是实体对象内部字段：

```js
{
  id, body, author, createdAt, updatedAt;
}
```

以及当前 slice 额外维护的字段：

```js
status;
errors;
```

如果业务实体不用 `id` 字段，也可以配置：

```js
const articleAdapter = createEntityAdapter({
  selectId: (article) => article.slug,
});
```

## 17. 评论列表请求成功后如何保存

`commentsSlice.js`：

```js
builder.addCase(getCommentsForArticle.fulfilled, (state, action) => {
  state.status = Status.SUCCESS;
  commentAdapter.setAll(state, action.payload);
});
```

这里：

```js
action.payload;
```

是 `getCommentsForArticle` 返回的评论数组。

`commentAdapter.setAll(state, action.payload)` 会把评论列表整体替换到 normalized state 中：

```js
state.comments.ids;
state.comments.entities;
```

然后：

```js
const commentSelectors = commentAdapter.getSelectors(selectCommentsSlice);

export const selectAllComments = commentSelectors.selectAll;
```

`selectAllComments` 会把 normalized state 转回数组，供组件使用：

```js
const comments = useSelector(selectAllComments);
```

## 18. 提交评论流程

`CommentForm`：

```js
function CommentForm() {
  const dispatch = useDispatch();
  const currentUser = useSelector(selectUser);
  const { slug } = useParams();
  const [body, setBody] = useState('');

  const saveComment = (event) => {
    event.preventDefault();
    dispatch(createComment({ articleSlug: slug, comment: { body } }));
    setBody('');
  };
}
```

流程：

```text
用户输入评论
  -> body 保存在 useState 中
  -> 提交表单
  -> dispatch(createComment({ articleSlug: slug, comment: { body } }))
  -> 清空输入框
```

`createComment`：

```js
export const createComment = createAsyncThunk(
  'comments/createComment',
  async ({ articleSlug, comment: newComment }, thunkApi) => {
    const { comment } = await agent.Comments.create(articleSlug, newComment);
    return comment;
  },
  {
    condition: (_, { getState }) =>
      selectIsAuthenticated(getState()) && !selectIsLoading(getState()),
    getPendingMeta: (_, { getState }) => ({ author: selectUser(getState()) }),
  }
);
```

请求：

```text
POST /articles/:slug/comments
body: { comment: { body: '...' } }
```

`condition` 表示：

```text
必须已登录
当前没有评论请求正在 loading
才允许提交评论
```

`getPendingMeta` 会在 pending action 上额外放入当前用户：

```js
action.meta.author;
```

## 19. 评论提交的乐观更新

pending 阶段：

```js
.addCase(createComment.pending, (state, action) => {
  state.status = Status.LOADING;

  if (action.meta.arg.comment.body) {
    commentAdapter.addOne(state, {
      ...action.meta.arg.comment,
      author: action.meta.author,
      id: action.meta.requestId,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    });
  }
})
```

这叫乐观更新：

```text
请求还没成功
先把评论临时插入列表
```

临时评论的数据来源：

```text
body：
  action.meta.arg.comment.body
  来自 dispatch(createComment({ comment: { body } }))

author：
  action.meta.author
  来自 getPendingMeta 里的 selectUser(getState())

id：
  action.meta.requestId
  createAsyncThunk 自动生成

createdAt / updatedAt：
  前端当前时间
```

成功后：

```js
.addCase(createComment.fulfilled, (state, action) => {
  state.status = Status.SUCCESS;
  commentAdapter.updateOne(state, {
    id: action.meta.requestId,
    changes: action.payload,
  });
  delete state.errors;
})
```

用后端返回的真实评论更新临时评论。

失败后：

```js
.addCase(createComment.rejected, (state, action) => {
  state.status = Status.FAILURE;
  state.errors = action.payload?.errors;
  commentAdapter.removeOne(state, action.meta.requestId);
});
```

把临时评论删掉，并保存错误。

## 20. 删除评论流程

`Comment` 中：

```js
const isAuthor = useSelector(selectIsAuthor(comment.id));

{
  isAuthor ? <DeleteCommentButton commentId={comment.id} /> : null;
}
```

只有评论作者本人能看到删除按钮。

`selectIsAuthor`：

```js
export const selectIsAuthor = (commentId) =>
  createSelector(
    selectCommentById(commentId),
    selectUser,
    (comment, currentUser) => currentUser?.username === comment?.author.username
  );
```

逻辑：

```text
根据 commentId 找到评论
读取当前登录用户
比较 currentUser.username 和 comment.author.username
```

删除按钮：

```js
const deleteComment = () => {
  dispatch(removeComment({ articleSlug: slug, commentId }));
};
```

`removeComment`：

```js
export const removeComment = createAsyncThunk(
  'comments/removeComment',
  async ({ articleSlug, commentId }) => {
    await agent.Comments.delete(articleSlug, commentId);
  },
  {
    condition: ({ commentId }, { getState }) =>
      selectIsAuthenticated(getState()) &&
      selectCommentsSlice(getState()).ids.includes(commentId) &&
      !selectIsLoading(getState()),
  }
);
```

请求：

```text
DELETE /articles/:slug/comments/:commentId
```

成功后：

```js
builder.addCase(removeComment.fulfilled, (state, action) => {
  state.status = Status.SUCCESS;
  commentAdapter.removeOne(state, action.meta.arg.commentId);
});
```

从 normalized state 中删除这条评论。

## 21. 完整流程总结

进入文章详情：

```text
点击文章
  -> URL 变成 /article/:slug
  -> React Router 渲染 Article
  -> useParams 取 slug
  -> dispatch(getArticle(slug))
  -> GET /articles/:slug
  -> articleSlice 保存 state.article.article
  -> 渲染标题、作者、正文、tag
```

加载评论：

```text
Article 渲染 CommentSection
  -> CommentSection 渲染 CommentList
  -> CommentList useParams 取 slug
  -> dispatch(getCommentsForArticle(slug))
  -> GET /articles/:slug/comments
  -> commentsSlice 用 commentAdapter.setAll 保存评论
  -> selectAllComments 转成数组
  -> CommentList 渲染每条评论
```

发表评论：

```text
登录用户输入评论
  -> dispatch(createComment({ articleSlug: slug, comment: { body } }))
  -> pending 阶段乐观插入临时评论
  -> POST /articles/:slug/comments
  -> 成功：用后端评论更新临时评论
  -> 失败：删除临时评论并显示错误
```

删除评论：

```text
判断当前用户是否评论作者
  -> 是作者才显示删除按钮
  -> 点击删除
  -> dispatch(removeComment({ articleSlug: slug, commentId }))
  -> DELETE /articles/:slug/comments/:commentId
  -> fulfilled 后 commentAdapter.removeOne 删除评论
```

这一节的核心是两套 Redux state 分工：

```text
state.article：
  当前文章详情

state.comments：
  当前文章的评论列表
```

文章详情页负责显示文章本体；评论模块单独负责评论的加载、创建、删除。
