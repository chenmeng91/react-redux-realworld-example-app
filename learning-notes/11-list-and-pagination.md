# 11. 列表页和分页

这一部分对应 `LEARNING.md` 里的“列表页和分页”，同时融合关于 `useSelector` 里的 `state`、slice reducer 里的 `state`、手写 thunk、箭头函数隐式返回、`action.payload.articles` 来源等追问。

主要参考文件：

- `src/components/Home/index.js`
- `src/components/Home/MainView.js`
- `src/components/ArticleList.js`
- `src/components/ListPagination.js`
- `src/reducers/articleList.js`
- `src/features/tags/TagsSidebar.js`
- `src/features/tags/tagsSlice.js`
- `src/agent.js`
- `src/app/store.js`

## 1. 首页列表整体结构

首页组件在 `src/components/Home/index.js`：

```js
function Home() {
  const dispatch = useDispatch();
  const isAuthenticated = useSelector(selectIsAuthenticated);

  useEffect(() => {
    const defaultTab = isAuthenticated ? 'feed' : 'all';
    const fetchArticles = dispatch(changeTab(defaultTab));

    return () => {
      dispatch(homePageUnloaded());
      fetchArticles.abort();
    };
  }, []);

  return (
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
  );
}
```

首页主要分三块：

```text
Banner：顶部标题区域
MainView：左侧 tab、文章列表、分页
TagsSidebar：右侧热门 tag
```

首次进入首页时，会根据登录状态决定默认 tab：

```js
const defaultTab = isAuthenticated ? 'feed' : 'all';
```

也就是：

```text
已登录：默认 Your Feed
未登录：默认 Global Feed
```

然后：

```js
dispatch(changeTab(defaultTab));
```

触发切换 tab，并加载文章列表。

## 2. changeTab 是手写 thunk

`src/reducers/articleList.js` 中：

```js
export const changeTab = (tab) => (dispatch) => {
  dispatch(articleListSlice.actions.changeTab(tab));
  return dispatch(getAllArticles());
};
```

它是一个手写 thunk。

展开写法是：

```js
export const changeTab = (tab) => {
  return (dispatch) => {
    dispatch(articleListSlice.actions.changeTab(tab));
    return dispatch(getAllArticles());
  };
};
```

所以：

```js
dispatch(changeTab('all'));
```

实际流程是：

```text
changeTab('all') 返回一个函数
  -> thunk middleware 执行这个函数
  -> 先 dispatch articleList/changeTab
  -> 再 dispatch getAllArticles()
```

这个 thunk 的作用是把两个动作组合起来：

```text
切换 tab
  -> 修改 state.articleList.tab
  -> 按新 tab 请求文章列表
```

如果不写 thunk，组件里就要写两次：

```js
dispatch(articleListSlice.actions.changeTab('all'));
dispatch(getAllArticles());
```

封装成 thunk 后，组件只需要：

```js
dispatch(changeTab('all'));
```

## 3. 手写 thunk 的基本规则

普通 action creator 返回 action 对象：

```js
const normalActionCreator = (payload) => {
  return {
    type: 'xxx',
    payload,
  };
};
```

thunk action creator 返回函数：

```js
const thunkActionCreator = (arg) => {
  return (dispatch, getState, extra) => {
    // 可以 dispatch
    // 可以 getState
    // 可以执行异步逻辑
  };
};
```

规则可以这样记：

```text
外层函数接收业务参数
内层函数接收 dispatch/getState/extra
需要外部拿到结果时，要 return dispatch(...)
异步和流程编排写在 thunk 中
reducer 只负责同步更新 state
```

这个项目里的 `changeTab`：

```js
export const changeTab = (tab) => (dispatch) => {
  dispatch(articleListSlice.actions.changeTab(tab));
  return dispatch(getAllArticles());
};
```

为什么要 `return`？

因为 `Home` 里有：

```js
const fetchArticles = dispatch(changeTab(defaultTab));
```

后面 cleanup 里调用：

```js
fetchArticles.abort();
```

`return dispatch(getAllArticles())` 会把 `getAllArticles` 返回的 promise-like 对象传出去，所以外部才能调用 `.abort()`。

如果不写 `return`：

```js
export const changeTab = (tab) => (dispatch) => {
  dispatch(articleListSlice.actions.changeTab(tab));
  dispatch(getAllArticles());
};
```

那外部拿到的是 `undefined`，无法调用：

```js
fetchArticles.abort();
```

## 4. articleList slice 的 state

`src/reducers/articleList.js` 中：

```js
const initialState = {
  articles: [],
  articlesCount: 0,
  currentPage: 0,
  articlesPerPage: 10,
  tab: undefined,
  tag: undefined,
  author: undefined,
  favorited: undefined,
};
```

这块 state 对应 store 里的：

```js
state.articleList;
```

大概结构是：

```js
state.articleList = {
  articles: [],
  articlesCount: 0,
  currentPage: 0,
  articlesPerPage: 10,
  tab: 'all',
  tag: undefined,
  author: undefined,
  favorited: undefined,
};
```

首页列表主要用：

```text
articles：当前页文章数组
articlesCount：总文章数
currentPage：当前页，从 0 开始
articlesPerPage：每页数量
tab：当前 tab，all/feed
tag：当前 tag 筛选
```

个人页会用：

```text
author：作者筛选
favorited：收藏筛选
```

## 5. 不同位置的 state 含义不同

你问过：

```js
const currentTab = useSelector((state) => state.articleList.tab);
```

这里的 `state` 是整个 Redux root state。

根据 `src/app/store.js`：

```js
reducer: {
  article: articleReducer,
  articleList: articlesReducer,
  auth: authReducer,
  comments: commentsReducer,
  common: commonReducer,
  profile: profileReducer,
  tags: tagsReducer,
}
```

所以完整 root state 大概是：

```js
state = {
  article: ...,
  articleList: ...,
  auth: ...,
  comments: ...,
  common: ...,
  profile: ...,
  tags: ...
};
```

因此：

```js
state.articleList.tab;
```

意思是从 root state 中取 `articleList` 这块 slice，再取 `tab`。

但在 `createSlice` 的 reducer 里：

```js
changeTab: (state, action) => {
  state.tab = action.payload;
  delete state.tag;
};
```

这里的 `state` 是当前 slice 的 state，也就是：

```js
state.articleList;
```

所以可以直接写：

```js
state.tab = action.payload;
```

而不是：

```js
state.articleList.tab = action.payload;
```

总结：

```text
useSelector((state) => ...)
  -> state 是整个 Redux root state

thunkApi.getState()
  -> 返回整个 Redux root state

createSlice reducers 里的 state
  -> 当前 slice 的 state

extraReducers 里的 state
  -> 当前 slice 的 state

selector 函数里的 state
  -> 通常也是整个 Redux root state
```

例如 `authSlice` 中：

```js
export const selectIsAuthenticated = createSelector(
  (state) => selectAuthSlice(state).token,
  selectUser,
  (token, user) => Boolean(token && user)
);
```

这里的 `state` 也是 root state。

`selectAuthSlice(state)` 再从 root state 中取出：

```js
state.auth;
```

## 6. MainView 的 tab 逻辑

`src/components/Home/MainView.js` 中：

```js
function MainView() {
  return (
    <div className="col-md-9">
      <div className="feed-toggle">
        <ul className="nav nav-pills outline-active">
          <YourFeedTab />
          <GlobalFeedTab />
          <TagFilterTab />
        </ul>
      </div>

      <ArticleList />
    </div>
  );
}
```

这里有三个 tab：

```text
YourFeedTab：登录后才显示
GlobalFeedTab：全局文章
TagFilterTab：点击 tag 后显示当前 tag
```

`YourFeedTab`：

```js
const isAuthenticated = useSelector(selectIsAuthenticated);
const currentTab = useSelector((state) => state.articleList.tab);
const isActiveTab = currentTab === 'feed';

if (!isAuthenticated) {
  return null;
}

const dispatchChangeTab = () => {
  dispatch(changeTab('feed'));
};
```

未登录时直接：

```js
return null;
```

所以不会显示 `Your Feed`。

`GlobalFeedTab`：

```js
const currentTab = useSelector((state) => state.articleList.tab);
const isActiveTab = currentTab === 'all';

const dispatchChangeTab = () => {
  dispatch(changeTab('all'));
};
```

点击后加载全局文章。

`TagFilterTab`：

```js
const tag = useSelector((state) => state.articleList.tag);

if (!tag) {
  return null;
}
```

只有当前有 tag 筛选时才显示。

## 7. getAllArticles 如何请求数据

`src/reducers/articleList.js` 中：

```js
export const getAllArticles = createAsyncThunk(
  'articleList/getAll',
  ({ page, author, tag, favorited } = {}, thunkApi) =>
    thunkApi.getState().articleList.tab === 'feed'
      ? agent.Articles.feed(page)
      : agent.Articles.all({
          page: page ?? thunkApi.getState().articleList.currentPage,
          author: author ?? thunkApi.getState().articleList.author,
          tag: tag ?? thunkApi.getState().articleList.tag,
          favorited: favorited ?? thunkApi.getState().articleList.favorited,
          limit: thunkApi.getState().articleList.articlesPerPage ?? 10,
        })
);
```

`createAsyncThunk` 的第二个参数是 `payloadCreator`。

这里没有写显式 `return`，是因为箭头函数用了隐式返回。

这种写法：

```js
(arg) => expression;
```

等价于：

```js
(arg) => {
  return expression;
};
```

所以当前代码等价于：

```js
export const getAllArticles = createAsyncThunk(
  'articleList/getAll',
  ({ page, author, tag, favorited } = {}, thunkApi) => {
    return thunkApi.getState().articleList.tab === 'feed'
      ? agent.Articles.feed(page)
      : agent.Articles.all({
          page: page ?? thunkApi.getState().articleList.currentPage,
          author: author ?? thunkApi.getState().articleList.author,
          tag: tag ?? thunkApi.getState().articleList.tag,
          favorited: favorited ?? thunkApi.getState().articleList.favorited,
          limit: thunkApi.getState().articleList.articlesPerPage ?? 10,
        });
  }
);
```

如果当前 tab 是：

```js
'feed';
```

请求：

```js
agent.Articles.feed(page);
```

也就是：

```text
GET /articles/feed
```

否则请求：

```js
agent.Articles.all(...)
```

也就是：

```text
GET /articles
```

并带上可能存在的参数：

```text
page
author
tag
favorited
limit
```

所以 `getAllArticles` 是一个“根据当前 Redux 状态决定请求什么列表”的统一入口。

## 8. agent 如何把 page 转成 offset

`src/agent.js` 中：

```js
get: (url, query = {}) => {
  if (Number.isSafeInteger(query?.page)) {
    query.limit = query.limit ? query.limit : 10;
    query.offset = query.page * query.limit;
  }
  delete query.page;

  const isEmptyQuery = query == null || Object.keys(query).length === 0;

  return agent(isEmptyQuery ? url : `${url}?${serialize(query)}`);
},
```

前端内部使用：

```text
page：第几页，从 0 开始
```

接口使用：

```text
limit：每页多少条
offset：跳过多少条
```

转换公式：

```js
offset = page * limit;
```

例子：

```text
page = 0, limit = 10 -> offset = 0
page = 1, limit = 10 -> offset = 10
page = 2, limit = 10 -> offset = 20
```

所以点击第 3 页时，内部 page 是 2，最终请求参数是：

```text
limit=10&offset=20
```

## 9. action.payload.articles 从哪里来

`getAllArticles.fulfilled`：

```js
builder.addCase(getAllArticles.fulfilled, (state, action) => {
  state.articles = action.payload.articles;
  state.articlesCount = action.payload.articlesCount;
  state.currentPage = action.meta.arg?.page ?? 0;
});
```

这里能访问：

```js
action.payload.articles;
action.payload.articlesCount;
```

是因为文章列表接口返回的数据结构就是：

```js
{
  articles: [...],
  articlesCount: 123
}
```

完整链路：

```text
getAllArticles payloadCreator
  -> return agent.Articles.all(...)
  -> agent.Articles.all 调用 /articles 接口
  -> 后端返回 { articles, articlesCount }
  -> createAsyncThunk 把返回值放进 fulfilled action.payload
  -> reducer 通过 action.payload.articles 读取文章数组
```

所以：

```js
state.articles = action.payload.articles;
```

是把接口返回的文章数组保存到：

```js
state.articleList.articles;
```

```js
state.articlesCount = action.payload.articlesCount;
```

是把接口返回的总数保存到：

```js
state.articleList.articlesCount;
```

注意：

```text
articles 和 articlesCount 不是 Redux 自动生成的字段
它们来自后端 /articles 接口的响应结构
```

## 10. ArticleList 如何显示文章

`src/components/ArticleList.js`：

```js
function ArticleList() {
  const articles = useSelector((state) => state.articleList.articles);

  if (!articles) {
    return <div className="article-preview">Loading...</div>;
  }

  if (articles.length === 0) {
    return <div className="article-preview">No articles are here... yet.</div>;
  }

  return (
    <>
      {articles.map((article) => (
        <ArticlePreview article={article} key={article.slug} />
      ))}

      <ListPagination />
    </>
  );
}
```

它从 Redux 读取：

```js
state.articleList.articles;
```

然后分三种情况：

```text
articles 不存在：显示 Loading
articles 是空数组：显示 No articles
articles 有数据：map 渲染 ArticlePreview，并显示分页
```

当前项目里 `initialState.articles` 是：

```js
[];
```

所以首次渲染更可能显示：

```text
No articles are here... yet.
```

而不是：

```text
Loading...
```

这说明这个 demo 对文章列表 loading 状态处理得比较简化。

## 11. ListPagination 如何计算页码

`src/components/ListPagination.js`：

```js
const articlesCount = useSelector((state) => state.articleList.articlesCount);
const currentPage = useSelector((state) => state.articleList.currentPage);
const articlesPerPage = useSelector(
  (state) => state.articleList.articlesPerPage
);
```

如果总文章数小于等于每页数量：

```js
if (articlesCount <= articlesPerPage) {
  return null;
}
```

就不显示分页。

页码数组：

```js
const pages = Array.from(
  { length: Math.ceil(articlesCount / articlesPerPage) },
  (_, number) => number
);
```

例如：

```text
articlesCount = 25
articlesPerPage = 10
Math.ceil(25 / 10) = 3
pages = [0, 1, 2]
```

页面上显示：

```js
{
  page + 1;
}
```

所以用户看到：

```text
1 2 3
```

但内部 page 是：

```text
0 1 2
```

## 12. 点击分页后的流程

分页点击：

```js
const handleClickPage = (page) => () => {
  dispatch(getAllArticles({ page }));
};
```

点击第 2 页：

```text
用户看到 2
内部 page = 1
dispatch(getAllArticles({ page: 1 }))
```

然后：

```text
getAllArticles 根据当前 tab/tag/author/favorited 决定请求参数
agent.requests.get 把 page 转成 offset
请求成功后 reducer 保存 articles/articlesCount/currentPage
分页重新渲染，当前页高亮
```

当前页高亮：

```js
const isActivePage = page === currentPage;
```

## 13. tag 筛选流程

右侧 tag 列表在 `src/features/tags/TagsSidebar.js`。

首次加载 tag：

```js
useEffect(() => {
  const fetchTags = dispatch(getAllTags());

  return () => {
    fetchTags.abort();
  };
}, []);
```

`getAllTags`：

```js
export const getAllTags = createAsyncThunk('tags/getAllTags', async () => {
  const { tags } = await agent.Tags.getAll();

  return tags;
});
```

点击 tag：

```js
const handleClickTag = (tag) => () => {
  dispatch(getArticlesByTag({ tag }));
};
```

`getArticlesByTag`：

```js
export const getArticlesByTag = createAsyncThunk(
  'articleList/getArticlesByTag',
  ({ tag, page } = {}) => agent.Articles.byTag(tag, page)
);
```

请求：

```js
byTag: (tag, page) => requests.get(`/articles`, { tag, page });
```

成功后：

```js
builder.addCase(getArticlesByTag.fulfilled, (state, action) => ({
  articles: action.payload.articles,
  articlesCount: action.payload.articlesCount,
  currentPage: action.meta.arg?.page ?? 0,
  tag: action.meta.arg?.tag,
  articlesPerPage: 10,
}));
```

这里会保存：

```js
state.articleList.tag = action.meta.arg?.tag;
```

所以 `TagFilterTab` 能显示当前 tag。

后续分页虽然调用的是：

```js
dispatch(getAllArticles({ page }));
```

但 `getAllArticles` 会读取当前 Redux state 里的 tag：

```js
tag: tag ?? thunkApi.getState().articleList.tag;
```

所以 tag 筛选下翻页仍然会带着当前 tag。

## 14. 首页列表完整流程

全局文章流程：

```text
进入 /
  -> Home mount
  -> defaultTab = 'all'
  -> dispatch(changeTab('all'))
  -> articleList.tab = 'all'
  -> dispatch(getAllArticles())
  -> agent.Articles.all(...)
  -> GET /articles?limit=10&offset=0
  -> fulfilled
  -> state.articleList.articles = 返回文章
  -> state.articleList.articlesCount = 总数
  -> ArticleList 重新渲染
  -> ListPagination 根据总数渲染页码
```

登录用户 feed 流程：

```text
进入 /
  -> defaultTab = 'feed'
  -> dispatch(changeTab('feed'))
  -> articleList.tab = 'feed'
  -> dispatch(getAllArticles())
  -> getAllArticles 发现 tab 是 feed
  -> agent.Articles.feed(page)
  -> GET /articles/feed
  -> fulfilled
  -> 渲染文章列表
```

tag 筛选流程：

```text
TagsSidebar 加载 tags
  -> 用户点击某个 tag
  -> dispatch(getArticlesByTag({ tag }))
  -> GET /articles?tag=xxx
  -> fulfilled
  -> state.articleList.tag = xxx
  -> TagFilterTab 显示 #xxx
  -> ArticleList 显示该 tag 的文章
  -> 分页点击 getAllArticles({ page })
  -> getAllArticles 从 state 读到 tag
  -> GET /articles?tag=xxx&limit=10&offset=...
```

分页流程：

```text
点击页码 2
  -> 内部 page = 1
  -> dispatch(getAllArticles({ page: 1 }))
  -> agent.requests.get 把 page 转成 offset
  -> offset = 1 * articlesPerPage
  -> 请求下一页
  -> fulfilled 后 currentPage = 1
  -> 页码 2 高亮
```

## 15. 这一节的核心理解

列表页最重要的点不是 UI，而是数据条件如何流动：

```text
tab/tag/page 等条件
  -> 存在 Redux state.articleList 中
  -> getAllArticles 根据当前 state 生成请求
  -> 请求成功后把 articles/articlesCount/currentPage 写回 state
  -> ArticleList 和 ListPagination 通过 useSelector 读取 state
  -> 页面重新渲染
```

一句话总结：

```text
列表页不是每个按钮都自己拼接口，
而是把 tab/tag/page 等条件集中放进 Redux state，
再由 getAllArticles 统一读取这些条件并请求数据。
```
