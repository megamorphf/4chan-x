Build =
  staticPath: '//s.4cdn.org/image/'
  gifIcon: if window.devicePixelRatio >= 2 then '@2x.gif' else '.gif'
  spoilerRange: {}

  unescape: (text) ->
    return text unless text?
    text.replace(/<[^>]*>/g, '').replace /&(amp|#039|quot|lt|gt|#44);/g, (c) ->
      {'&amp;': '&', '&#039;': "'", '&quot;': '"', '&lt;': '<', '&gt;': '>', '&#44;': ','}[c]

  shortFilename: (filename) ->
    ext = filename.match(/\.?[^\.]*$/)[0]
    if filename.length - ext.length > 30
      "#{filename.match(/(?:[\uD800-\uDBFF][\uDC00-\uDFFF]|[^]){0,25}/)[0]}(...)#{ext}"
    else
      filename

  spoilerThumb: (boardID) ->
    if spoilerRange = Build.spoilerRange[boardID]
      # Randomize the spoiler image.
      "#{Build.staticPath}spoiler-#{boardID}#{Math.floor 1 + spoilerRange * Math.random()}.png"
    else
      "#{Build.staticPath}spoiler.png"

  sameThread: (boardID, threadID) ->
    g.VIEW is 'thread' and g.BOARD.ID is boardID and g.THREADID is +threadID

  postURL: (boardID, threadID, postID) ->
    if Build.sameThread boardID, threadID
      "#p#{postID}"
    else
      "/#{boardID}/thread/#{threadID}#p#{postID}"

  parseJSON: (data, boardID) ->
    o =
      # id
      postID:   data.no
      threadID: data.resto or data.no
      boardID:  boardID
      isReply:  !!data.resto
      # thread status
      isSticky: !!data.sticky
      isClosed: !!data.closed
      isArchived: !!data.archived
      # file status
      fileDeleted: !!data.filedeleted
    o.info =
      subject:  Build.unescape data.sub
      email:    Build.unescape data.email
      name:     Build.unescape(data.name) or ''
      tripcode: data.trip
      uniqueID: data.id
      flagCode: data.country
      flag:     Build.unescape data.country_name
      dateUTC:  data.time
      dateText: data.now
      commentHTML: {innerHTML: data.com or ''}
    if data.capcode
      o.info.capcode = data.capcode.replace(/_highlight$/, '').replace(/_/g, ' ').replace(/\b\w/g, (c) -> c.toUpperCase())
      o.capcodeHighlight = /_highlight$/.test data.capcode
      delete o.info.uniqueID
    if data.ext
      o.file =
        name:      (Build.unescape data.filename) + data.ext
        url: if boardID is 'f'
          "#{location.protocol}//i.4cdn.org/#{boardID}/#{encodeURIComponent data.filename}#{data.ext}"
        else
          "#{location.protocol}//i.4cdn.org/#{boardID}/#{data.tim}#{data.ext}"
        height:    data.h
        width:     data.w
        MD5:       data.md5
        size:      $.bytesToString data.fsize
        thumbURL:  "#{location.protocol}//i.4cdn.org/#{boardID}/#{data.tim}s.jpg"
        theight:   data.tn_h
        twidth:    data.tn_w
        isSpoiler: !!data.spoiler
        tag:       data.tag
      o.file.dimensions = "#{o.file.width}x#{o.file.height}" unless /\.pdf$/.test o.file.url
    o

  parseComment: (html) ->
    html = html
      .replace(/<br\b[^<]*>/gi, '\n')
      .replace(/\n\n<span\b[^<]* class="abbr"[^]*$/i, '') # EXIF data (/p/)
      .replace(/^<b\b[^<]*>Rolled [^<]*<\/b>/i, '')       # Rolls (/tg/)
      .replace(/<span\b[^<]* class="fortune"[^]*$/i, '')  # Fortunes (/s4s/)
      .replace(/<[^>]*>/g, '')
    Build.unescape html

  postFromObject: (data, boardID, suppressThumb) ->
    o = Build.parseJSON data, boardID
    Build.post o, suppressThumb

  post: (o, suppressThumb) ->
    {postID, threadID, boardID, file} = o
    {subject, email, name, tripcode, capcode, uniqueID, flagCode, flag, dateUTC, dateText, commentHTML} = o.info
    {staticPath, gifIcon} = Build

    ### Post Info ###

    if capcode
      capcodeLC = capcode.toLowerCase()
      if capcode is 'Founder'
        capcodePlural      = 'the Founder'
        capcodeDescription = "4chan's Founder"
      else
        capcodeLong   = {'Admin': 'Administrator', 'Mod': 'Moderator'}[capcode] or capcode
        capcodePlural = "#{capcodeLong}s"
        capcodeDescription = "a 4chan #{capcodeLong}"

    postLink = Build.postURL boardID, threadID, postID
    quoteLink = if Build.sameThread boardID, threadID
      "javascript:quote('#{+postID}');"
    else
      "/#{boardID}/thread/#{threadID}#q#{postID}"

    postInfo = <%= readHTML('PostInfo.html') %>

    ### File Info ###

    if file
      protocol = /^https?:(?=\/\/i\.4cdn\.org\/)/
      fileURL = file.url.replace protocol, ''
      shortFilename = Build.shortFilename file.name
      fileThumb = if file.isSpoiler then Build.spoilerThumb(boardID) else file.thumbURL.replace(protocol, '')

    fileBlock = <%= readHTML('File.html') %>

    ### Whole Post ###

    postClass = if o.isReply then 'reply' else 'op'

    wholePost = <%= readHTML('Post.html') %>

    container = $.el 'div',
      className: "postContainer #{postClass}Container"
      id:        "pc#{postID}"
    $.extend container, wholePost

    # Fix quotelinks
    for quote in $$ '.quotelink', container
      href = quote.getAttribute 'href'
      if (href[0] is '#') and !(Build.sameThread boardID, threadID)
        quote.href = "/#{boardID}/thread/#{threadID}" + href
      else if (match = href.match /^\/([^\/]+)\/thread\/(\d+)/) and (Build.sameThread match[1], match[2])
        quote.href = href.match(/(#[^#]*)?$/)[0] or '#'
      else if /^\d+(#|$)/.test(href) and not (g.VIEW is 'thread' and g.BOARD.ID is boardID) # used on /f/
        quote.href = "/#{boardID}/thread/#{href}"

    container

  summaryText: (status, posts, files) ->
    text = ''
    text += "#{status} " if status
    text += "#{posts} post#{if posts > 1 then 's' else ''}"
    text += " and #{files} image repl#{if files > 1 then 'ies' else 'y'}" if +files
    text += " #{if status is '-' then 'shown' else 'omitted'}."

  summary: (boardID, threadID, posts, files) ->
    $.el 'a',
      className: 'summary'
      textContent: Build.summaryText '', posts, files
      href: "/#{boardID}/thread/#{threadID}"

  thread: (board, data, OP) ->
    if (root = OP.nodes.root.parentNode)
      $.rmAll root
    else
      root = $.el 'div',
        className: 'thread'
        id: "t#{data.no}"
    $.add root, Build.hat.cloneNode(false) if Build.hat
    $.add root, OP.nodes.root
    if data.omitted_posts or !Conf['Show Replies'] and data.replies
      [posts, files] = if Conf['Show Replies']
        # XXX data.omitted_images is not accurate.
        [data.omitted_posts, data.images - data.last_replies.filter((data) -> !!data.ext).length]
      else
        [data.replies, data.images]
      summary = Build.summary board.ID, data.no, posts, files
      $.add root, summary
    root

  catalogThread: (thread) ->
    {staticPath, gifIcon} = Build
    data = Index.liveThreadDict[thread.ID]

    if data.spoiler and !Conf['Reveal Spoiler Thumbnails']
      src = "#{staticPath}spoiler"
      if spoilerRange = Build.spoilerRange[thread.board]
        # Randomize the spoiler image.
        src += "-#{thread.board}" + Math.floor 1 + spoilerRange * Math.random()
      src += '.png'
      imgClass = 'spoiler-file'
    else if data.filedeleted
      src = "#{staticPath}filedeleted-res#{gifIcon}"
      imgClass = 'deleted-file'
    else if thread.OP.file
      src = thread.OP.file.thumbURL
    else
      src = "#{staticPath}nofile.png"
      imgClass = 'no-file'

    postCount = data.replies + 1
    fileCount = data.images  + !!data.ext
    pageCount = Index.liveThreadIDs.indexOf(thread.ID) // Index.threadsNumPerPage + 1

    root = $.el 'div',
      className: 'catalog-thread post' # post added to make 4chan postInfo CSS work

    $.extend root, <%= readHTML('CatalogThread.html') %>

    root.dataset.fullID = thread.fullID
    $.addClass root, thread.OP.highlights... if thread.OP.highlights
    $.addClass root, 'noFile' unless thread.OP.file

    root
