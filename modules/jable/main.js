const siteBaseUrl = "https://jable.tv";
const userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36";
const channel = "Jable";

const slugPattern = /^[a-zA-Z0-9][a-zA-Z0-9._-]{0,127}$/;
const videoPathPattern = /\/videos\/([a-zA-Z0-9][a-zA-Z0-9._-]{0,127})\/?$/;
const categoryPathPattern = /\/categories\/([^/?#]+)\/?$/;
const tagPathPattern = /\/(?:tags|models)\/([^/?#]+)\/?$/;
const pageParamPattern = /(?:from|from_videos)[:=]([0-9]{1,7})/i;
const pagePathPattern = /\/([0-9]{1,7})\/?$/;
const hlsVarPattern = /\bhlsUrl\s*=\s*["'](https?:\/\/[^"']+\.m3u8[^"']*)["']/i;
const hlsDirectPattern = /https?:\/\/[^\s"'<>\\]+\.m3u8(?:\?[^\s"'<>\\]*)?/i;

function truncate(text, limit) {
  const trimmed = String(text || "").trim();
  const characters = Array.from(trimmed);
  return characters.length <= limit ? trimmed : characters.slice(0, limit).join("") + "...";
}

function firstNonEmpty(...values) {
  for (const value of values) {
    if (typeof value === "string" && value.trim() !== "") {
      return value.trim();
    }
  }
  return "";
}

function pad2(value) {
  return value < 10 ? "0" + value : String(value);
}

function normalizeDate(text) {
  const matches = String(text || "").trim().match(/\d{4}-\d{1,2}-\d{1,2}/g) || [];
  for (const match of matches) {
    const [year, month, day] = match.split("-").map((part) => parseInt(part, 10));
    if (year >= 2000 && year <= 2100 && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
      return year + "-" + pad2(month) + "-" + pad2(day);
    }
  }
  return "";
}

function parseAddress(raw) {
  try {
    return host.parseUrl(raw);
  } catch (error) {
    return null;
  }
}

function htmlUnescape(text) {
  const named = { amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: "\u00a0" };
  return String(text || "").replace(/&(#[xX][0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);/g, (entity, body) => {
    if (body[0] === "#") {
      const code = body[1] === "x" || body[1] === "X" ? parseInt(body.slice(2), 16) : parseInt(body.slice(1), 10);
      return code > 0 && code <= 0x10ffff ? String.fromCodePoint(code) : entity;
    }
    return Object.prototype.hasOwnProperty.call(named, body) ? named[body] : entity;
  });
}

function resolveUrl(base, ref) {
  ref = htmlUnescape(String(ref || "")).trim();
  if (ref === "") {
    return "";
  }
  ref = ref.replace(/\\\//g, "/");
  if (ref.startsWith("//")) {
    return "https:" + ref;
  }
  const parsed = parseAddress(ref);
  if (!parsed) {
    return ref;
  }
  let resolved = parsed.href;
  if (parsed.scheme === "") {
    try {
      resolved = host.resolveUrl(base, ref);
    } catch (error) {
      return ref;
    }
  }
  return resolved.replace(/^http:/, "https:");
}

function pathEscape(text) {
  const kept = { "%24": "$", "%26": "&", "%2B": "+", "%2C": ",", "%3A": ":", "%3B": ";", "%3D": "=", "%40": "@" };
  return encodeURIComponent(text)
    .replace(/[!'()*]/g, (character) => "%" + character.charCodeAt(0).toString(16).toUpperCase())
    .replace(/%(?:24|26|2B|2C|3A|3B|3D|40)/g, (escaped) => kept[escaped]);
}

function htmlTree(body) {
  if (body.length > 4 << 20) {
    throw new Error("站源页面过大");
  }
  const root = host.parseHtml(body);
  const pending = [root];
  while (pending.length > 0) {
    const node = pending.pop();
    for (const child of node.children || []) {
      child.parent = node;
      pending.push(child);
    }
  }
  return root;
}

function htmlNodes(root, match) {
  const found = [];
  if (!root) {
    return found;
  }
  const pending = [root];
  while (pending.length > 0) {
    const node = pending.pop();
    if (match(node)) {
      found.push(node);
    }
    const children = node.children || [];
    for (let index = children.length - 1; index >= 0; index--) {
      pending.push(children[index]);
    }
  }
  return found;
}

function htmlAttr(node, name) {
  return node && node.attrs && typeof node.attrs[name] === "string" ? node.attrs[name] : "";
}

function htmlClass(node, name) {
  return htmlAttr(node, "class").split(/\s+/).includes(name);
}

function htmlFirstClass(root, name) {
  return htmlNodes(root, (node) => htmlClass(node, name))[0] || null;
}

function htmlText(root) {
  const parts = [];
  for (const node of htmlNodes(root, (node) => node.tag === undefined && typeof node.text === "string")) {
    if (node.parent && (node.parent.tag === "script" || node.parent.tag === "style")) {
      continue;
    }
    parts.push(node.text);
  }
  return parts.join(" ").split(/\s+/).filter((part) => part !== "").join(" ");
}

function tagged(...names) {
  return (node) => names.includes(node.tag);
}

function validCategory(category) {
  if (category === "") {
    return true;
  }
  return category.length <= 96 && !/[/\\?#\x00\r\n]/.test(category);
}

function coverAddress(raw) {
  raw = String(raw || "").trim();
  if (raw === "" || raw.startsWith("data:")) {
    return "";
  }
  const parsed = parseAddress(resolveUrl(siteBaseUrl + "/", raw));
  if (!parsed || (parsed.scheme !== "https" && parsed.scheme !== "http") || parsed.hostname === "" || parsed.userInfo) {
    return "";
  }
  return parsed.href;
}

function pathMatch(href, pattern) {
  const parsed = parseAddress(String(href || "").trim());
  if (!parsed) {
    return "";
  }
  const match = parsed.path.match(pattern);
  return match ? match[1] : "";
}

function videoSlug(href) {
  return pathMatch(href, videoPathPattern);
}

function categorySlug(href) {
  return pathMatch(href, categoryPathPattern).trim();
}

function metadataOf(document) {
  const metadata = {};
  for (const node of htmlNodes(document, tagged("meta"))) {
    const key = firstNonEmpty(htmlAttr(node, "property"), htmlAttr(node, "name"));
    const value = htmlAttr(node, "content").trim();
    if (key !== "" && value !== "" && !metadata[key]) {
      metadata[key] = value;
    }
  }
  return metadata;
}

function heading(document) {
  for (const node of htmlNodes(document, tagged("h4", "h1"))) {
    const text = htmlText(node);
    if (text !== "") {
      return text;
    }
  }
  return "";
}

function cardImage(card) {
  let fallback = null;
  for (const image of htmlNodes(card, tagged("img"))) {
    const source = firstNonEmpty(htmlAttr(image, "data-src"), htmlAttr(image, "data-original"));
    if (source !== "" && !source.startsWith("data:")) {
      return image;
    }
    if (fallback === null) {
      const plain = htmlAttr(image, "src");
      if (plain !== "" && !plain.startsWith("data:")) {
        fallback = image;
      }
    }
  }
  return fallback;
}

function parseCards(document) {
  const cards = htmlNodes(document, (node) => node.tag === "div" && htmlClass(node, "video-img-box"));
  const items = [];
  const seen = new Set();
  for (const card of cards) {
    if (items.length >= 500) {
      break;
    }
    let slug = "";
    for (const anchor of htmlNodes(card, tagged("a"))) {
      slug = videoSlug(htmlAttr(anchor, "href"));
      if (slug !== "") {
        break;
      }
    }
    if (slug === "" || seen.has(slug)) {
      continue;
    }
    const image = cardImage(card);
    const titleNode = htmlFirstClass(card, "title") || htmlNodes(card, tagged("h6"))[0] || null;
    let title = firstNonEmpty(
      titleNode ? htmlText(titleNode) : "",
      image ? htmlAttr(image, "alt") : "",
      slug.toUpperCase(),
    );
    const cover = image === null ? "" : coverAddress(firstNonEmpty(htmlAttr(image, "data-src"), htmlAttr(image, "data-original"), htmlAttr(image, "src")));
    const badgeNode = htmlFirstClass(card, "label");
    seen.add(slug);
    items.push({
      id: host.dramaId(slug),
      source: host.source,
      sourceId: slug,
      title: truncate(title, 512),
      name: truncate(title, 512),
      cover,
      coverUrl: cover,
      channelName: channel,
      categoryName: "视频",
      remark: truncate(badgeNode ? htmlText(badgeNode) : "", 32),
    });
  }
  return items;
}

function hasMorePages(document, page) {
  let maxPage = 0;
  for (const anchor of htmlNodes(document, tagged("a"))) {
    const params = htmlAttr(anchor, "data-parameters");
    const paramMatch = params.match(pageParamPattern);
    if (paramMatch) {
      maxPage = Math.max(maxPage, parseInt(paramMatch[1], 10));
    }
    const href = htmlAttr(anchor, "href");
    const hrefParam = href.match(pageParamPattern);
    if (hrefParam) {
      maxPage = Math.max(maxPage, parseInt(hrefParam[1], 10));
    }
    if (htmlClass(anchor, "page-link")) {
      const num = parseInt(htmlText(anchor), 10);
      if (!isNaN(num)) {
        maxPage = Math.max(maxPage, num);
      }
      const pathNum = href.match(pagePathPattern);
      if (pathNum) {
        maxPage = Math.max(maxPage, parseInt(pathNum[1], 10));
      }
    }
  }
  return maxPage > page;
}

function tagsOf(document) {
  const tags = [];
  for (const anchor of htmlNodes(document, tagged("a"))) {
    const href = htmlAttr(anchor, "href");
    if (pathMatch(href, tagPathPattern) === "" && categorySlug(href) === "") {
      continue;
    }
    const text = htmlText(anchor);
    if (text === "" || tags.includes(text) || Array.from(text).length > 48) {
      continue;
    }
    tags.push(text);
    if (tags.length >= 16) {
      break;
    }
  }
  return tags;
}

function mediaAddress(body) {
  const varMatch = String(body || "").match(hlsVarPattern);
  if (varMatch && varMatch[1]) {
    return htmlUnescape(varMatch[1]).replace(/\\\//g, "/");
  }
  const direct = String(body || "").match(hlsDirectPattern);
  return direct ? htmlUnescape(direct[0]).replace(/\\\//g, "/") : "";
}

function isChallengePage(body) {
  if (!body || body.length > 60000) return false;
  const text = String(body).toLowerCase();
  return text.includes("just a moment") ||
    text.includes("cf-browser-verification") ||
    text.includes("cf_chl_opt") ||
    (text.includes("<title>attention required") && text.includes("cloudflare"));
}

function fetchBody(address) {
  let body = "";
  try {
    body = host.fetchText({ url: address, referer: siteBaseUrl + "/", userAgent }).body || "";
  } catch (error) {
    throw new Error("CF_CHALLENGE Jable 请求被拦截，请手动完成验证后重试");
  }
  if (isChallengePage(body)) {
    throw new Error("CF_CHALLENGE Jable 触发 Cloudflare 人机验证，请手动完成验证后重试");
  }
  return body;
}

function fetchDocument(address) {
  return htmlTree(fetchBody(address));
}

function buildCatalogUrl(page, category, query) {
  if (query !== "") {
    const base = siteBaseUrl + "/search/" + pathEscape(query) + "/";
    return page <= 1
      ? base
      : base + "?mode=async&function=get_block&block_id=list_videos_videos_list_search_result&q=" + encodeURIComponent(query) + "&sort_by=&from_videos=" + page;
  }
  if (category === "hot") {
    const base = siteBaseUrl + "/hot/";
    return page <= 1
      ? base
      : base + "?mode=async&function=get_block&block_id=list_videos_common_videos_list&sort_by=video_viewed_week&from=" + page;
  }
  if (category !== "") {
    const base = siteBaseUrl + "/categories/" + pathEscape(category) + "/";
    return page <= 1
      ? base
      : base + "?mode=async&function=get_block&block_id=list_videos_common_videos_list&sort_by=post_date&from=" + page;
  }
  const base = siteBaseUrl + "/latest-updates/";
  return page <= 1
    ? base
    : base + "?mode=async&function=get_block&block_id=list_videos_latest_videos_list&sort_by=post_date&from=" + page;
}

function fetchCatalogPage(page, category, query) {
  if (page < 1 || page > 1000000 || query.length > 256 || !validCategory(category)) {
    throw new Error("Jable 目录查询参数无效");
  }
  const document = fetchDocument(buildCatalogUrl(page, category, query));
  const items = parseCards(document);
  const hasMore = hasMorePages(document, page);
  if (items.length === 0 && (hasMore || (page === 1 && query === "" && category === ""))) {
    throw new Error("Jable 未返回应有的目录页，请重试");
  }
  return { items, hasMore };
}

module.exports = {
  validCategory,

  categories() {
    const document = fetchDocument(siteBaseUrl + "/categories/");
    const order = ["hot"];
    const names = { hot: "热门" };
    for (const anchor of htmlNodes(document, tagged("a"))) {
      const slug = categorySlug(htmlAttr(anchor, "href"));
      if (slug === "" || !validCategory(slug)) {
        continue;
      }
      const titleNode = htmlNodes(anchor, tagged("h4"))[0] || anchor;
      const name = htmlText(titleNode);
      if (name === "") {
        continue;
      }
      if (!Object.prototype.hasOwnProperty.call(names, slug)) {
        names[slug] = name;
        order.push(slug);
      } else if (Array.from(name).length < Array.from(names[slug]).length) {
        names[slug] = name;
      }
    }
    return order.slice(0, 200).map((slug) => ({ id: slug, name: truncate(names[slug], 48) }));
  },

  catalogPage(page, category) {
    return fetchCatalogPage(page, category, "");
  },

  search(page, query) {
    query = String(query || "").trim();
    if (query === "" || query.length > 256) {
      throw new Error("Jable 搜索关键词无效");
    }
    return fetchCatalogPage(page, "", query);
  },

  detail(sourceId) {
    if (!slugPattern.test(sourceId)) {
      throw new Error("Jable 视频 ID 无效");
    }
    const pageUrl = siteBaseUrl + "/videos/" + sourceId + "/";
    const document = fetchDocument(pageUrl);
    const metadata = metadataOf(document);
    const title = firstNonEmpty(heading(document), metadata["og:title"], metadata["twitter:title"]);
    if (title === "") {
      throw new Error("Jable 详情缺少视频标题");
    }
    const description = firstNonEmpty(metadata["og:description"], metadata["description"]);
    const cover = coverAddress(firstNonEmpty(metadata["og:image"], metadata["twitter:image"]));
    const drama = {
      id: host.dramaId(sourceId),
      source: host.source,
      sourceId,
      title: truncate(title, 512),
      name: truncate(title, 512),
      desc: truncate(description, 12000),
      intro: truncate(description, 12000),
      cover,
      coverUrl: cover,
      channelName: channel,
      categoryName: "视频",
      onlineDate: normalizeDate(metadata["og:video:release_date"]),
      tags: tagsOf(document),
      totalEpisode: 1,
      episodeCount: 1,
    };
    const chapter = {
      id: host.chapterId(sourceId, sourceId),
      source: host.source,
      title: "正片",
      currentEpisode: 1,
      videoUrl: "jable-play://" + sourceId,
      pageUrl,
      referer: pageUrl,
    };
    return { drama, chapters: [chapter] };
  },

  resolveMedia(task) {
    const dramaPrefix = host.source + ":";
    const sourceId = task.dramaId.startsWith(dramaPrefix) ? task.dramaId.slice(dramaPrefix.length).trim() : "";
    if (!slugPattern.test(sourceId) || !task.chapter.id.startsWith(host.chapterId(sourceId, ""))) {
      throw new Error("Jable 播放分集信息无效，请刷新详情");
    }
    const pageUrl = siteBaseUrl + "/videos/" + sourceId + "/";
    const body = fetchBody(pageUrl);
    const address = mediaAddress(body);
    if (address === "") {
      throw new Error("Jable 页面里未解析到播放地址");
    }
    return host.prepareWebMedia({ url: address, referer: pageUrl }, channel);
  },
};
