Settings =
  init: ->
    # Appchan X settings link
    link = $.el 'a',
      id:          'appchanOptions'
      className:   'settings-link'
      href:        'javascript:;'
    $.on link, 'click', Settings.open

    $.asap (-> d.body), ->
      return unless Main.isThisPageLegit()
      # Wait for #boardNavMobile instead of #boardNavDesktop,
      # it might be incomplete otherwise.
      $.asap (-> $.id 'boardNavMobile'), ->
        $.prepend $.id('navtopright'), [$.tn(' ['), link, $.tn('] ')]

    $.get 'previousversion', null, (item) ->
      if previous = item['previousversion']
        return if previous is g.VERSION
        # Avoid conflicts between sync'd newer versions
        # and out of date extension on this device.
        prev = previous.match(/\d+/g).map Number
        curr = g.VERSION.match(/\d+/g).map Number
        return unless prev[0] <= curr[0] and prev[1] <= curr[1] and prev[2] <= curr[2]

        changelog = '<%= meta.repo %>blob/<%= meta.mainBranch %>/CHANGELOG.md'
        el = $.el 'span',
          innerHTML: "<%= meta.name %> has been updated to <a href='#{changelog}' target=_blank>version #{g.VERSION}</a>."
        new Notification 'info', el, 30
      else
        $.on d, '4chanXInitFinished', Settings.open
      $.set
        lastupdate: Date.now()
        previousversion: g.VERSION

    Settings.addSection 'Style',    Settings.style
    Settings.addSection 'Themes',   Settings.themes
    Settings.addSection 'Mascots',  Settings.mascots
    Settings.addSection 'Script',   Settings.main
    Settings.addSection 'Filter',   Settings.filter
    Settings.addSection 'Sauce',    Settings.sauce
    Settings.addSection 'Rice',     Settings.rice
    Settings.addSection 'Keybinds', Settings.keybinds
    $.on d, 'AddSettingsSection',   Settings.addSection
    $.on d, 'OpenSettings',         (e) -> Settings.open e.detail

    return if Conf['Enable 4chan\'s Extension']
    settings = JSON.parse(localStorage.getItem '4chan-settings') or {}
    return if settings.disableAll
    settings.disableAll = true
    localStorage.setItem '4chan-settings', JSON.stringify settings

  open: (openSection) ->
    if Conf['editMode'] is "theme"
      if confirm "Opening the options dialog will close and discard any theme changes made with the theme editor."
        ThemeTools.close()
      return

    if Conf['editMode'] is "mascot"
      if confirm "Opening the options dialog will close and discard any mascot changes made with the mascot editor."
        MascotTools.close()
      return

    return if Settings.overlay
    $.event 'CloseMenu'

    Settings.dialog = dialog = $.el 'div',
      id:    'appchanx-settings'
      class: 'dialog'
      innerHTML: """
        <nav>
          <div class=sections-list></div>
          <div class=credits>
            <a href='<%= meta.page %>' target=_blank><%= meta.name %></a> |
            <a href='<%= meta.repo %>blob/<%= meta.mainBranch %>/CHANGELOG.md' target=_blank>#{g.VERSION}</a> |
            <a href='<%= meta.repo %>blob/<%= meta.mainBranch %>/CONTRIBUTING.md#reporting-bugs' target=_blank>Issues</a> |
            <a href=javascript:; class=close title=Close>×</a>
          </div>
        </nav>
        <hr>
        <div class=section-container><section></section></div>"""

    Settings.overlay = overlay = $.el 'div',
      id: 'overlay'

    links = []
    for section in Settings.sections
      link = $.el 'a',
        className: "tab-#{section.hyphenatedTitle}"
        textContent: section.title
        href: 'javascript:;'
      $.on link, 'click', Settings.openSection.bind section
      links.push link
      sectionToOpen = link if section.title is openSection
    $.add $('.sections-list', dialog), links
    (if sectionToOpen then sectionToOpen else links[0]).click()

    $.on $('.close', dialog), 'click', Settings.close
    $.on overlay,             'click', Settings.close

    d.body.style.width = "#{d.body.clientWidth}px"
    $.addClass d.body, 'unscroll'
    $.add d.body, [overlay, dialog]

  close: ->
    return unless Settings.dialog
    d.body.style.removeProperty 'width'
    $.rmClass d.body, 'unscroll'
    $.rm Settings.overlay
    $.rm Settings.dialog
    delete Settings.overlay
    delete Settings.dialog

  sections: []

  addSection: (title, open) ->
    if typeof title isnt 'string'
      {title, open} = title.detail
    hyphenatedTitle = title.toLowerCase().replace /\s+/g, '-'
    Settings.sections.push {title, hyphenatedTitle, open}

  openSection: (mode)->
    if selected = $ '.tab-selected', Settings.dialog
      $.rmClass selected, 'tab-selected'
    $.addClass $(".tab-#{@hyphenatedTitle}", Settings.dialog), 'tab-selected'
    section = $ 'section', Settings.dialog
    section.innerHTML = null
    section.className = "section-#{@hyphenatedTitle}"
    @open section, mode
    section.scrollTop = 0

  main: (section) ->
    section.innerHTML = """
      <div class=imp-exp>
        <button class=export>Export Settings</button>
        <button class=import>Import Settings</button>
        <input type=file style='visibility:hidden'>
      </div>
      <p class=imp-exp-result></p>
    """
    $.on $('.export', section), 'click',  Settings.export
    $.on $('.import', section), 'click',  Settings.import
    $.on $('input',   section), 'change', Settings.onImport

    items  = {}
    inputs = {}
    for key, obj of Config.main
      fs = $.el 'fieldset',
        innerHTML: "<legend>#{key}</legend>"
      for key, arr of obj
        description = arr[1]
        div = $.el 'div',
          innerHTML: "<label><input type=checkbox name='#{key}'>#{key}</label><span class=description>#{description}</span>"
        input = $ 'input', div
        $.on $('label', div), 'mouseover', Settings.mouseover
        $.on input, 'change', $.cb.checked
        items[key]  = Conf[key]
        inputs[key] = input
        $.add fs, div
      Rice.nodes fs
      $.add section, fs

    $.get items, (items) ->
      for key, val of items
        inputs[key].checked = val
      return

    div = $.el 'div',
      innerHTML: "<button></button><span class=description>: Clear manually-hidden threads and posts on all boards. Refresh the page to apply."
    button = $ 'button', div
    hiddenNum = 0
    $.get 'hiddenThreads', boards: {}, (item) ->
      for ID, board of item.hiddenThreads.boards
        for ID, thread of board
          hiddenNum++
      button.textContent = "Hidden: #{hiddenNum}"
    $.get 'hiddenPosts', boards: {}, (item) ->
      for ID, board of item.hiddenPosts.boards
        for ID, thread of board
          for ID, post of thread
            hiddenNum++
      button.textContent = "Hidden: #{hiddenNum}"
    $.on button, 'click', ->
      @textContent = 'Hidden: 0'
      $.get 'hiddenThreads', boards: {}, (item) ->
        for boardID of item.hiddenThreads.boards
          localStorage.removeItem "4chan-hide-t-#{boardID}"
        $.delete ['hiddenThreads', 'hiddenPosts']
    $.after $('input[name="Stubs"]', section).parentNode.parentNode, div

  export: (now, data) ->
    unless typeof now is 'number'
      now  = Date.now()
      data =
        version: g.VERSION
        date: now
      Conf['WatchedThreads'] = {}
      for db in DataBoards
        Conf[db] = boards: {}
      # Make sure to export the most recent data.
      $.get Conf, (Conf) ->
        data.Conf = Conf
        Settings.export now, data
      return
    a = $.el 'a',
      className: 'warning'
      textContent: 'Save me!'
      download: "<%= meta.name %> v#{g.VERSION}-#{now}.json"
      href: "data:application/json;base64,#{btoa unescape encodeURIComponent JSON.stringify data, null, 2}"
      target: '_blank'
    if $.engine isnt 'gecko'
      a.click()
      return
    # XXX Firefox won't let us download automatically.
    p = $ '.imp-exp-result', Settings.dialog
    p.innerHTML = null
    $.add p, a

  import: ->
    @nextElementSibling.click()

  onImport: ->
    return unless file = @files[0]
    output = @parentNode.nextElementSibling
    unless confirm 'Your current settings will be entirely overwritten, are you sure?'
      output.textContent = 'Import aborted.'
      return
    reader = new FileReader()
    reader.onload = (e) ->
      try
        data = JSON.parse e.target.result
        Settings.loadSettings data
        if confirm 'Import successful. Refresh now?'
          window.location.reload()
      catch err
        output.textContent = 'Import failed due to an error.'
        c.error err.stack
    reader.readAsText file

  loadSettings: (data) ->
    version = data.version.split '.'
    if version[0] is '2'
      data = Settings.convertSettings data,
        # General confs
        'Disable 4chan\'s extension': ''
        'Catalog Links': ''
        'Reply Navigation': ''
        'Show Stubs': 'Stubs'
        'Image Auto-Gif': 'Auto-GIF'
        'Expand From Current': ''
        'Unread Favicon': 'Unread Tab Icon'
        'Post in Title': 'Thread Excerpt'
        'Auto Hide QR': ''
        'Open Reply in New Tab': ''
        'Remember QR size': ''
        'Quote Inline': 'Quote Inlining'
        'Quote Preview': 'Quote Previewing'
        'Indicate OP quote': 'Mark OP Quotes'
        'Indicate Cross-thread Quotes': 'Mark Cross-thread Quotes'
        # filter
        'uniqueid': 'uniqueID'
        'mod': 'capcode'
        'country': 'flag'
        'md5': 'MD5'
        # keybinds
        'openEmptyQR': 'Open empty QR'
        'openQR': 'Open QR'
        'openOptions': 'Open settings'
        'close': 'Close'
        'spoiler': 'Spoiler tags'
        'code': 'Code tags'
        'submit': 'Submit QR'
        'watch': 'Watch'
        'update': 'Update'
        'unreadCountTo0': ''
        'expandAllImages': 'Expand images'
        'expandImage': 'Expand image'
        'zero': 'Front page'
        'nextPage': 'Next page'
        'previousPage': 'Previous page'
        'nextThread': 'Next thread'
        'previousThread': 'Previous thread'
        'expandThread': 'Expand thread'
        'openThreadTab': 'Open thread'
        'openThread': 'Open thread tab'
        'nextReply': 'Next reply'
        'previousReply': 'Previous reply'
        'hide': 'Hide'
        # updater
        'Scrolling': 'Auto Scroll'
        'Verbose': ''
      data.Conf.sauces = data.Conf.sauces.replace /\$\d/g, (c) ->
        switch c
          when '$1'
            '%TURL'
          when '$2'
            '%URL'
          when '$3'
            '%MD5'
          when '$4'
            '%board'
          else
            c
      for key, val of Config.hotkeys
        continue unless key of data.Conf
        data.Conf[key] = data.Conf[key].replace(/ctrl|alt|meta/g, (s) -> "#{s[0].toUpperCase()}#{s[1..]}").replace /(^|.+\+)[A-Z]$/g, (s) ->
          "Shift+#{s[0...-1]}#{s[-1..].toLowerCase()}"
      data.Conf.WatchedThreads = data.WatchedThreads
    $.set data.Conf

  convertSettings: (data, map) ->
    for prevKey, newKey of map
      data.Conf[newKey] = data.Conf[prevKey] if newKey
      delete data.Conf[prevKey]
    data

  filter: (section) ->
    section.innerHTML = """
      <select name=filter>
        <option value=guide>Guide</option>
        <option value=name>Name</option>
        <option value=uniqueID>Unique ID</option>
        <option value=tripcode>Tripcode</option>
        <option value=capcode>Capcode</option>
        <option value=email>E-mail</option>
        <option value=subject>Subject</option>
        <option value=comment>Comment</option>
        <option value=flag>Flag</option>
        <option value=filename>Filename</option>
        <option value=dimensions>Image dimensions</option>
        <option value=filesize>Filesize</option>
        <option value=MD5>Image MD5</option>
      </select>
      <div></div>
    """
    select = $ 'select', section
    $.on select, 'change', Settings.selectFilter
    Settings.selectFilter.call select

  selectFilter: ->
    div = @nextElementSibling
    if (name = @value) isnt 'guide'
      div.innerHTML = null
      ta = $.el 'textarea',
        name: name
        className: 'field'
        spellcheck: false
      $.get name, Conf[name], (item) ->
        ta.value = item[name]
      $.on ta, 'change', $.cb.value
      $.add div, ta
      return
    div.innerHTML = """
      <div class=warning #{if Conf['Filter'] then 'hidden' else ''}><code>Filter</code> is disabled.</div>
      <p>
        Use <a href=https://developer.mozilla.org/en/JavaScript/Guide/Regular_Expressions>regular expressions</a>, one per line.<br>
        Lines starting with a <code>#</code> will be ignored.<br>
        For example, <code>/weeaboo/i</code> will filter posts containing the string `<code>weeaboo</code>`, case-insensitive.<br>
        MD5 filtering uses exact string matching, not regular expressions.
      </p>
      <ul>You can use these settings with each regular expression, separate them with semicolons:
        <li>
          Per boards, separate them with commas. It is global if not specified.<br>
          For example: <code>boards:a,jp;</code>.
        </li>
        <li>
          Filter OPs only along with their threads (`only`), replies only (`no`), or both (`yes`, this is default).<br>
          For example: <code>op:only;</code>, <code>op:no;</code> or <code>op:yes;</code>.
        </li>
        <li>
          Overrule the `Show Stubs` setting if specified: create a stub (`yes`) or not (`no`).<br>
          For example: <code>stub:yes;</code> or <code>stub:no;</code>.
        </li>
        <li>
          Highlight instead of hiding. You can specify a class name to use with a userstyle.<br>
          For example: <code>highlight;</code> or <code>highlight:wallpaper;</code>.
        </li>
        <li>
          Highlighted OPs will have their threads put on top of board pages by default.<br>
          For example: <code>top:yes;</code> or <code>top:no;</code>.
        </li>
      </ul>
    """

  sauce: (section) ->
    section.innerHTML = """
      <div class=warning #{if Conf['Sauce'] then 'hidden' else ''}><code>Sauce</code> is disabled.</div>
      <div>Lines starting with a <code>#</code> will be ignored.</div>
      <div>You can specify a display text by appending <code>;text:[text]</code> to the URL.</div>
      <ul>These parameters will be replaced by their corresponding values:
        <li><code>%TURL</code>: Thumbnail URL.</li>
        <li><code>%URL</code>: Full image URL.</li>
        <li><code>%MD5</code>: MD5 hash.</li>
        <li><code>%board</code>: Current board.</li>
      </ul>
      <textarea name=sauces class=field spellcheck=false></textarea>
    """
    sauce = $ 'textarea', section
    $.get 'sauces', Conf['sauces'], (item) ->
      sauce.value = item['sauces']
    $.on sauce, 'change', $.cb.value

  rice: (section) ->
    section.innerHTML = """
      <fieldset>
        <legend>Custom Board Navigation <span class=warning #{if Conf['Custom Board Navigation'] then 'hidden' else ''}>is disabled.</span></legend>
        <div><input name=boardnav class=field spellcheck=false></div>
        <div>In the following, <code>board</code> can translate to a board ID (<code>a</code>, <code>b</code>, etc...), the current board (<code>current</code>), or the Status/Twitter link (<code>status</code>, <code>@</code>).</div>
        <div>Board link: <code>board</code></div>
        <div>Title link: <code>board-title</code></div>
        <div>Full text link: <code>board-full</code></div>
        <div>Custom text link: <code>board-text:"VIP Board"</code></div>
        <div>Index-only link: <code>board-index</code></div>
        <div>Catalog-only link: <code>board-catalog</code></div>
        <div>Combinations are possible: <code>board-index-text:"VIP Index"</code></div>
        <div>Full board list toggle: <code>toggle-all</code></div>
      </fieldset>

      <fieldset>
        <legend>Time Formatting <span class=warning #{if Conf['Time Formatting'] then 'hidden' else ''}>is disabled.</span></legend>
        <div><input name=time class=field spellcheck=false>: <span class=time-preview></span></div>
        <div>Supported <a href=//en.wikipedia.org/wiki/Date_%28Unix%29#Formatting>format specifiers</a>:</div>
        <div>Day: <code>%a</code>, <code>%A</code>, <code>%d</code>, <code>%e</code></div>
        <div>Month: <code>%m</code>, <code>%b</code>, <code>%B</code></div>
        <div>Year: <code>%y</code></div>
        <div>Hour: <code>%k</code>, <code>%H</code>, <code>%l</code>, <code>%I</code>, <code>%p</code>, <code>%P</code></div>
        <div>Minute: <code>%M</code></div>
        <div>Second: <code>%S</code></div>
      </fieldset>

      <fieldset>
        <legend>Quote Backlinks formatting <span class=warning #{if Conf['Quote Backlinks'] then 'hidden' else ''}>is disabled.</span></legend>
        <div><input name=backlink class=field spellcheck=false>: <span class=backlink-preview></span></div>
      </fieldset>

      <fieldset>
        <legend>File Info Formatting <span class=warning #{if Conf['File Info Formatting'] then 'hidden' else ''}>is disabled.</span></legend>
        <div><input name=fileInfo class=field spellcheck=false>: <span class='fileText file-info-preview'></span></div>
        <div>Link: <code>%l</code> (truncated), <code>%L</code> (untruncated), <code>%T</code> (Unix timestamp)</div>
        <div>Original file name: <code>%n</code> (truncated), <code>%N</code> (untruncated), <code>%t</code> (Unix timestamp)</div>
        <div>Spoiler indicator: <code>%p</code></div>
        <div>Size: <code>%B</code> (Bytes), <code>%K</code> (KB), <code>%M</code> (MB), <code>%s</code> (4chan default)</div>
        <div>Resolution: <code>%r</code> (Displays 'PDF' for PDF files)</div>
      </fieldset>

      <fieldset>
        <legend>Unread Tab Icon <span class=warning #{if Conf['Unread Tab Icon'] then 'hidden' else ''}>is disabled.</span></legend>
        <select name=favicon>
          <option value=ferongr>ferongr</option>
          <option value=xat->xat-</option>
          <option value=Mayhem>Mayhem</option>
          <option value=Original>Original</option>
        </select>
        <span class=favicon-preview></span>
      </fieldset>

      <fieldset>
        <legend><input type=checkbox name='Custom CSS' #{if Conf['Custom CSS'] then 'checked' else ''}> Custom CSS</legend>
        <button id=apply-css>Apply CSS</button>
        <textarea name=usercss class=field spellcheck=false #{if Conf['Custom CSS'] then '' else 'disabled'}></textarea>
      </fieldset>
    """
    items = {}
    inputs = {}
    for name in ['boardnav', 'time', 'backlink', 'fileInfo', 'favicon', 'usercss']
      input = $ "[name='#{name}']", section
      items[name]  = Conf[name]
      inputs[name] = input
      event = if ['favicon', 'usercss'].contains name
        'change'
      else
        'input'
      $.on input, event, $.cb.value
    $.get items, (items) ->
      for key, val of items
        input = inputs[key]
        input.value = val
        unless 'usercss' is name
          $.on input, event, Settings[key]
          Settings[key].call input
      return
    Rice.nodes section
    $.on $('input[name="Custom CSS"]', section), 'change', Settings.togglecss
    $.on $.id('apply-css'), 'click', Settings.usercss

  boardnav: ->
    Header.generateBoardList @value

  time: ->
    funk = Time.createFunc @value
    @nextElementSibling.textContent = funk Time, new Date()

  backlink: ->
    @nextElementSibling.textContent = Conf['backlink'].replace /%id/, '123456789'

  fileInfo: ->
    data =
      isReply: true
      file:
        URL: '//images.4chan.org/g/src/1334437723720.jpg'
        name: 'd9bb2efc98dd0df141a94399ff5880b7.jpg'
        size: '276 KB'
        sizeInBytes: 276 * 1024
        dimensions: '1280x720'
        isImage: true
        isSpoiler: true
    funk = FileInfo.createFunc @value
    @nextElementSibling.innerHTML = funk FileInfo, data

  favicon: ->
    Favicon.switch()
    Unread.update() if g.VIEW is 'thread' and Conf['Unread Tab Icon']
    @nextElementSibling.innerHTML = """
      <img src=#{Favicon.default}>
      <img src=#{Favicon.unreadSFW}>
      <img src=#{Favicon.unreadNSFW}>
      <img src=#{Favicon.unreadDead}>
      """

  togglecss: ->
    if $('textarea', @parentNode.parentNode).disabled = !@checked
      CustomCSS.rmStyle()
    else
      CustomCSS.addStyle()
    $.cb.checked.call @

  usercss: ->
    CustomCSS.update()

  keybinds: (section) ->
    section.innerHTML = """
      <div class=warning #{if Conf['Keybinds'] then 'hidden' else ''}><code>Keybinds</code> are disabled.</div>
      <div>Allowed keys: <kbd>a-z</kbd>, <kbd>0-9</kbd>, <kbd>Ctrl</kbd>, <kbd>Shift</kbd>, <kbd>Alt</kbd>, <kbd>Meta</kbd>, <kbd>Enter</kbd>, <kbd>Esc</kbd>, <kbd>Up</kbd>, <kbd>Down</kbd>, <kbd>Right</kbd>, <kbd>Left</kbd>.</div>
      <div>Press <kbd>Backspace</kbd> to disable a keybind.</div>
      <table><tbody>
        <tr><th>Actions</th><th>Keybinds</th></tr>
      </tbody></table>
    """
    tbody  = $ 'tbody', section
    items  = {}
    inputs = {}
    for key, arr of Config.hotkeys
      tr = $.el 'tr',
        innerHTML: "<td>#{arr[1]}</td><td><input class=field></td>"
      input = $ 'input', tr
      input.name = key
      input.spellcheck = false
      items[key]  = Conf[key]
      inputs[key] = input
      $.on input, 'keydown', Settings.keybind
      Rice.nodes tr
      $.add tbody, tr

    $.get items, (items) ->
      for key, val of items
        inputs[key].value = val
      return

  keybind: (e) ->
    return if e.keyCode is 9 # tab
    e.preventDefault()
    e.stopPropagation()
    return unless (key = Keybinds.keyCode e)?
    @value = key
    $.cb.value.call @

  style: (section) ->
    nodes  = $.frag()
    items  = {}
    inputs = {}

    for key, obj of Config.style

      fs = $.el 'fieldset',
        innerHTML: "<legend>#{key}</legend>"

      for key, arr of obj
        [value, description, type] = arr

        div = $.el 'div',
          className: 'styleoption'

        if type

          if type is 'text'

            div.innerHTML = "<div class=option><span class=optionlabel>#{key}</span></div><div class=description>#{description}</div><div class=option><input name='#{key}' style=width: 100%></div>"
            input = $ "input", div

          else

            html = "<div class=option><span class=optionlabel>#{key}</span></div><div class=description>#{description}</div><div class=option><select name='#{key}'>"
            for name in type
              html += "<option value='#{name}'>#{name}</option>"
            html += "</select></div>"
            div.innerHTML = html
            input = $ "select", div

        else

          div.innerHTML = "<div class=option><label><input type=checkbox name='#{key}'>#{key}</label></div><span style='display:none;'>#{description}</span>"
          input = $ 'input', div
          input.bool = true

        items[key]  = Conf[key]
        inputs[key] = input

        $.on $('.option', div), 'mouseover', Settings.mouseover

        $.on input, 'change', Settings.change

        $.add fs, div
      $.add nodes, fs

    $.get items, (items) ->
      for key, val of items
        input = inputs[key]
        if input.bool
          input.checked = val
          Rice.checkbox input
        else
          input.value   = val
          if input.nodeName is 'SELECT'
            Rice.select input

      $.add section, nodes


  change: ->
    $.cb[if @bool then 'checked' else 'value'].call @
    Style.addStyle()

  themes: (section, mode) ->
    if typeof mode isnt 'string'
      mode = 'default'

    parentdiv  = $.el 'div',
      id:        "themeContainer"

    suboptions = $.el 'div',
      className: "suboptions"
      id:        "themes"

    keys = Object.keys(Themes)
    keys.sort()

    if mode is "default"

      for name in keys
        theme = Themes[name]

        unless theme["Deleted"]

          div = $.el 'div',
            className: "theme #{if name is Conf['theme'] then 'selectedtheme' else ''}"
            id:        name
            innerHTML: "
<div style='cursor: pointer; position: relative; margin-bottom: 2px; width: 100% !important; box-shadow: none !important; background:#{theme['Reply Background']}!important;border:1px solid #{theme['Reply Border']}!important;color:#{theme['Text']}!important'>
  <div>
    <div style='cursor: pointer; width: 9px; height: 9px; margin: 2px 3px; display: inline-block; vertical-align: bottom; background: #{theme['Checkbox Background']}; border: 1px solid #{theme['Checkbox Border']};'></div>
    <span style='color:#{theme['Subjects']}!important; font-weight: 600 !important'>
      #{name}
    </span>
    <span style='color:#{theme['Names']}!important; font-weight: 600 !important'>
      #{theme['Author']}
    </span>
    <span style='color:#{theme['Sage']}!important'>
      (SAGE)
    </span>
    <span style='color:#{theme['Tripcodes']}!important'>
      #{theme['Author Tripcode']}
    </span>
    <time style='color:#{theme['Timestamps']}'>
      20XX.01.01 12:00
    </time>
    <a onmouseout='this.setAttribute(&quot;style&quot;,&quot;color:#{theme['Post Numbers']}!important&quot;)' onmouseover='this.setAttribute(&quot;style&quot;,&quot;color:#{theme['Hovered Links']}!important;&quot;)' style='color:#{theme['Post Numbers']}!important;' href='javascript:;'>
      No.27583594
    </a>
    <a onmouseout='this.setAttribute(&quot;style&quot;,&quot;color:#{theme['Backlinks']}!important;&quot;)' onmouseover='this.setAttribute(&quot;style&quot;,&quot;color:#{theme['Hovered Links']}!important;&quot;)' style='color:#{theme['Backlinks']}!important;' href='javascript:;' name='#{name}' class=edit>
      &gt;&gt;edit
    </a>
    <a onmouseout='this.setAttribute(&quot;style&quot;,&quot;color:#{theme['Backlinks']}!important;&quot;)' onmouseover='this.setAttribute(&quot;style&quot;,&quot;color:#{theme['Hovered Links']}!important;&quot;)' style='color:#{theme['Backlinks']}!important;' href='javascript:;' name='#{name}' class=export>
      &gt;&gt;export
    </a>
    <a onmouseout='this.setAttribute(&quot;style&quot;,&quot;color:#{theme['Backlinks']}!important;&quot;)' onmouseover='this.setAttribute(&quot;style&quot;,&quot;color:#{theme['Hovered Links']}!important;&quot;)' style='color:#{theme['Backlinks']}!important;' href='javascript:;' name='#{name}' class=delete>
      &gt;&gt;delete
    </a>
  </div>
  <blockquote style='margin: 0; padding: 12px 40px 12px 38px'>
    <a style='color:#{theme['Quotelinks']}!important; text-shadow: none;'>
      &gt;&gt;27582902
    </a>
    <br>
    Post content is right here.
  </blockquote>
  <h1 style='color: #{theme['Text']}'>
    Selected
  </h1>
</div>"

          div.style.backgroundColor = theme['Background Color']

          $.on $('a.edit', div), 'click', (e) ->
            e.preventDefault()
            e.stopPropagation()
            ThemeTools.init @name
            Settings.close()

          $.on $('a.export', div), 'click', (e) ->
            e.preventDefault()
            e.stopPropagation()
            exportTheme = Themes[@name]
            exportTheme['Theme'] = @name
            exportedTheme = "data:application/json," + encodeURIComponent(JSON.stringify(exportTheme))

            if window.open exportedTheme, "_blank"
              return
            else if confirm "Your popup blocker is preventing Appchan X from exporting this theme. Would you like to open the exported theme in this window?"
              window.location exportedTheme

          $.on $('a.delete', div), 'click', (e) ->
            e.preventDefault()
            e.stopPropagation()
            container = $.id @name

            unless container.previousSibling or container.nextSibling
              alert "Cannot delete theme (No other themes available)."
              return

            if confirm "Are you sure you want to delete \"#{@name}\"?"
              if @name is Conf['theme']
                if settheme = container.previousSibling or container.nextSibling
                  Conf['theme'] = settheme.id
                  $.addClass settheme, 'selectedtheme'
                  $.set 'theme', Conf['theme']
              Themes[@name]["Deleted"] = true
              userThemes = $.get "userThemes", {}
              userThemes[@name] = Themes[@name]
              $.set 'userThemes', userThemes
              $.rm container

          $.on div, 'click', Settings.selectTheme
          $.add suboptions, div

      div = $.el 'div',
        id:        'addthemes'
        innerHTML: "
<a id=newtheme href='javascript:;'>New Theme</a> /
 <a id=import href='javascript:;'>Import Theme</a><input id=importbutton type=file hidden> /
 <a id=SSimport href='javascript:;'>Import from 4chan SS</a><input id=SSimportbutton type=file hidden> /
 <a id=OCimport href='javascript:;'>Import from Oneechan</a><input id=OCimportbutton type=file hidden> /
 <a id=tUndelete href='javascript:;'>Undelete Theme</a>
"

      $.on $("#newtheme", div), 'click', ->
        ThemeTools.init "untitled"
        Settings.close()

      $.on $("#import", div), 'click', ->
        @nextSibling.click()
      $.on $("#importbutton", div), 'change', (evt) ->
        ThemeTools.importtheme "appchan", evt

      $.on $("#OCimport", div), 'click', ->
        @nextSibling.click()
      $.on $("#OCimportbutton", div), 'change', (evt) ->
        ThemeTools.importtheme "oneechan", evt

      $.on $("#SSimportbutton", div), 'change', (evt) ->
        ThemeTools.importtheme "SS", evt
      $.on $("#SSimport", div), 'click', ->
        @nextSibling.click()

      $.on $('#tUndelete', div), 'click', ->
        $.rm $.id "themeContainer"
        Settings.openSection themes, 'undelete'

    else

      for name in keys
        theme = Themes[name]

        if theme["Deleted"]

          div = $.el 'div',
            id:        name
            className: theme
            innerHTML: "
<div style='cursor: pointer; position: relative; margin-bottom: 2px; width: 100% !important; box-shadow: none !important; background:#{theme['Reply Background']}!important;border:1px solid #{theme['Reply Border']}!important;color:#{theme['Text']}!important'>
  <div style='padding: 3px 0px 0px 8px;'>
    <span style='color:#{theme['Subjects']}!important; font-weight: 600 !important'>#{name}</span>
    <span style='color:#{theme['Names']}!important; font-weight: 600 !important'>#{theme['Author']}</span>
    <span style='color:#{theme['Sage']}!important'>(SAGE)</span>
    <span style='color:#{theme['Tripcodes']}!important'>#{theme['Author Tripcode']}</span>
    <time style='color:#{theme['Timestamps']}'>20XX.01.01 12:00</time>
    <a onmouseout='this.setAttribute(&quot;style&quot;,&quot;color:#{theme['Post Numbers']}!important&quot;)' onmouseover='this.setAttribute(&quot;style&quot;,&quot;color:#{theme['Hovered Links']}!important&quot;)' style='color:#{theme['Post Numbers']}!important;' href='javascript:;'>No.27583594</a>
  </div>
  <blockquote style='margin: 0; padding: 12px 40px 12px 38px'>
    <a style='color:#{theme['Quotelinks']}!important; text-shadow: none;'>
      &gt;&gt;27582902
    </a>
    <br>
    I forgive you for using VLC to open me. ;__;
  </blockquote>
</div>"

          $.on div, 'click', ->
            if confirm "Are you sure you want to undelete \"#{@id}\"?"
              Themes[@id]["Deleted"] = false
              $.get "userThemes", {}, (item) ->
                userThemes = item["userThemes"]
                userThemes[@id] = Themes[@id]
                $.set 'userThemes', userThemes
                $.rm @

          $.add suboptions, div

      div = $.el 'div',
        id:        'addthemes'
        innerHTML: "<a href='javascript:;'>Return</a>"

      $.on $('a', div), 'click', ->
        $.rm $.id "themeContainer"
        Settings.openSection themes

    $.add parentdiv, suboptions
    $.add parentdiv, div
    $.add section, parentdiv

  selectTheme: ->
    if currentTheme = $.id(Conf['theme'])
      $.rmClass currentTheme, 'selectedtheme'

    if Conf["NSFW/SFW Themes"]
      $.set "theme_#{g.TYPE}", @id
    else
      $.set "theme", @id
    Conf['theme'] = @id
    $.addClass @, 'selectedtheme'
    Style.addStyle()

  mouseover: (e) ->
    mouseover = $.el 'div',
      id:        'mouseover'
      className: 'dialog'

    $.add Header.hover, mouseover

    mouseover.innerHTML = @nextElementSibling.innerHTML

    UI.hover
      root:         @
      el:           mouseover
      latestEvent:  e
      endEvents:    'mouseout'
      asapTest: ->  true
      close:        true

    return


  mascots: (section, mode) ->
    ul = {}
    categories = []

    if typeof mode isnt 'string'
      mode = 'default'

    parentdiv = $.el "div",
      id: "mascotContainer"

    suboptions = $.el "div",
      className: "suboptions"

    mascotHide = $.el "div",
      id: "mascot_hide"
      className: "reply"
      innerHTML: "Hide Categories <span></span><div></div>"

    keys = Object.keys Mascots
    keys.sort()

    if mode is 'default'
      # Create a keyed Unordered List Element and hide option for each mascot category.
      for category in MascotTools.categories
        ul[category] = $.el "ul",
          className: "mascots"
          id: category

        if Conf["Hidden Categories"].contains category
          ul[category].hidden = true

        header = $.el "h3",
          className: "mascotHeader"
          textContent: category

        categories.push option = $.el "label",
          name: category
          innerHTML: "<input name='#{category}' type=checkbox #{if Conf["Hidden Categories"].contains(category) then 'checked' else ''}>#{category}"

        $.on $('input', option), 'change', ->
          Settings.mascotTab.toggle.call @

        $.add ul[category], header
        $.add suboptions, ul[category]

      for name in keys
        unless Conf["Deleted Mascots"].contains name
          mascot = Mascots[name]
          li = $.el 'li',
            className: 'mascot'
            id: name
            innerHTML: "
<div class='mascotname'>#{name.replace /_/g, " "}</div>
<div class='mascotcontainer'><div class='mAlign #{mascot.category}'><img class=mascotimg src='#{if Array.isArray(mascot.image) then (if Style.lightTheme then mascot.image[1] else mascot.image[0]) else mascot.image}'></div></div>
<div class='mascotoptions'><a class=edit name='#{name}' href='javascript:;'>Edit</a><a class=delete name='#{name}' href='javascript:;'>Delete</a><a class=export name='#{name}' href='javascript:;'>Export</a></div>"

          if Conf[g.MASCOTSTRING].contains name
            $.addClass li, 'enabled'

          $.on $('a.edit', li), 'click', (e) ->
            e.stopPropagation()
            MascotTools.dialog @name
            Settings.close()

          $.on $('a.delete', li), 'click', (e) ->
            e.stopPropagation()
            if confirm "Are you sure you want to delete \"#{@name}\"?"
              if Conf['mascot'] is @name
                MascotTools.init()
              for type in ["Enabled Mascots", "Enabled Mascots sfw", "Enabled Mascots nsfw"]
                Conf[type].remove @name
                $.set type, Conf[type]
              Conf["Deleted Mascots"].push @name
              $.set "Deleted Mascots", Conf["Deleted Mascots"]
              $.rm $.id @name

          # Mascot Exporting
          $.on $('a.export', li), 'click', (e) ->
            e.stopPropagation()
            exportMascot = Mascots[@name]
            exportMascot['Mascot'] = @name
            exportedMascot = "data:application/json," + encodeURIComponent(JSON.stringify(exportMascot))

            if window.open exportedMascot, "_blank"
              return
            else if confirm "Your popup blocker is preventing Appchan X from exporting this theme. Would you like to open the exported theme in this window?"
              window.location exportedMascot

          $.on li, 'click', ->
            if Conf[g.MASCOTSTRING].remove @id
              if Conf['mascot'] is @id
                MascotTools.init()
            else
              Conf[g.MASCOTSTRING].push @id
              MascotTools.init @id
            $.toggleClass @, 'enabled'
            $.set g.MASCOTSTRING, Conf[g.MASCOTSTRING]

          if MascotTools.categories.contains mascot.category
            $.add ul[mascot.category], li
          else
            $.add ul[MascotTools.categories[0]], li

      $.add $('div', mascotHide), categories

      batchmascots = $.el 'div',
        id: "mascots_batch"
        innerHTML: "
<a href=\"javascript:;\" id=clear>Clear All</a> /
<a href=\"javascript:;\" id=selectAll>Select All</a> /
<a href=\"javascript:;\" id=createNew>Add Mascot</a> /
<a href=\"javascript:;\" id=importMascot>Import Mascot</a><input id=importMascotButton type=file hidden> /
<a href=\"javascript:;\" id=undelete>Undelete Mascots</a> /
<a href=\"http://appchan.booru.org/\" target=_blank>Get More Mascots!</a>
  "

      $.on $('#clear', batchmascots), 'click', ->
        enabledMascots = JSON.parse(JSON.stringify(Conf[g.MASCOTSTRING]))
        for name in enabledMascots
          $.rmClass $.id(name), 'enabled'
        $.set g.MASCOTSTRING, Conf[g.MASCOTSTRING] = []

      $.on $('#selectAll', batchmascots), 'click', ->
        for name, mascot of Mascots
          unless Conf["Hidden Categories"].contains(mascot.category) or Conf[g.MASCOTSTRING].contains(name) or Conf["Deleted Mascots"].contains(name)
            $.addClass $.id(name), 'enabled'
            Conf[g.MASCOTSTRING].push name
        $.set g.MASCOTSTRING, Conf[g.MASCOTSTRING]

      $.on $('#createNew', batchmascots), 'click', ->
        MascotTools.dialog()
        Settings.close()

      $.on $("#importMascot", batchmascots), 'click', ->
        @nextSibling.click()

      $.on $("#importMascotButton", batchmascots), 'change', (evt) ->
        MascotTools.importMascot evt

      $.on $('#undelete', batchmascots), 'click', ->
        unless Conf["Deleted Mascots"].length > 0
          alert "No mascots have been deleted."
          return
        $.rm $.id "mascotContainer"
        Settings.mascotTab.dialog Settings.el, 'undelete'

    else
      ul = $.el "ul",
        className: "mascots"
        id: category

      for name in keys
        if Conf["Deleted Mascots"].contains name
          mascot = Mascots[name]
          li = $.el 'li',
            className: 'mascot'
            id: name
            innerHTML: "
  <div class='mascotname'>#{name.replace /_/g, " "}</span>
  <div class='container #{mascot.category}'><img class=mascotimg src='#{if Array.isArray(mascot.image) then (if Style.lightTheme then mascot.image[1] else mascot.image[0]) else mascot.image}'></div>
  "

          $.on li, 'click', ->
            if confirm "Are you sure you want to undelete \"#{@id}\"?"
              Conf["Deleted Mascots"].remove @id
              $.set "Deleted Mascots", Conf["Deleted Mascots"]
              $.rm @

          $.add ul, li

      $.add suboptions, ul

      batchmascots = $.el 'div',
        id: "mascots_batch"
        innerHTML: "<a href=\"javascript:;\" id=\"return\">Return</a>"

      $.on $('#return', batchmascots), 'click', ->
        $.rm $.id "mascotContainer"
        Settings.section 'mascots'

    $.add parentdiv, [suboptions, batchmascots, mascotHide]

    Rice.nodes parentdiv

    $.add section, parentdiv