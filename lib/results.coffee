# TODO: esc key to remove current result
# In general this is weird and needs a refactor

tree = require './tree'

module.exports =
  timeout: (t, f) -> setTimeout f, t

  header: ->
    header = document.createElement 'div'
    header.classList.add 'header'
    header

  body: ->
    body = document.createElement 'div'
    body.classList.add 'body'
    body

  collapsible: (opts) ->
    view = document.createElement 'div'
    header = @header()
    body = @body()
    view.appendChild header
    view.appendChild body
    header.innerText = opts.header
    body.innerText = opts.body
    view

  result: (ed, opts) ->
    view = document.createElement 'div'
    view.classList.add 'ink', 'inline', 'result'
    view.style.position = 'relative'
    view.style.top = -ed.getLineHeightInPixels() + 'px'
    view.style.left = '10px'
    view.style.pointerEvents = 'auto'
    view.appendChild @collapsible opts
    view: view

  methods: (r) ->
    r.destroy = => @remove r
    r.invalidate = => @invalidate r
    r.validate = => @validate r

  show: (ed, mark, {watch, header, body}={}) ->
    mark.getBufferRange().isReversed and throw "Cannot add result to reversed marker"
    flag = @removeLines ed, mark.getHeadBufferPosition().row,
                            mark.getTailBufferPosition().row
    result = @result ed,
      header: header
      body: body
    mark.result = result
    result.editor = ed
    result.marker = mark
    result.text = @text result
    result.decorator = ed.decorateMarker mark,
      type: 'overlay'
      item: result.view
    @methods result
    setTimeout (-> result.view.parentElement.style.pointerEvents = 'none'), 10
    if !flag
      result.view.classList.add 'ink-hide'
      @timeout 20, =>
        result.view.classList.remove 'ink-hide'
    watch != false and @watchText result
    @watchNewline result
    result

  lineRange: (ed, start, end) ->
    [[start, 0], [end, ed.lineTextForBufferRow(end).length]]

  showForRange: (ed, range, opts) ->
    mark = ed.markBufferRange range
    result = @show ed, mark, opts
    result.ownsMark = true
    return result

  showForLines: (ed, start, end, opts) ->
    @showForRange ed, @lineRange(ed, start, end), opts

  remove: (result) ->
    result.view.classList.add 'ink-hide'
    @timeout 200, =>
      result.decorator.destroy()
      result.ownsMark and result.marker.destroy()
      result.editorWatch?.dispose()
      result.newlineWatch?.dispose()

  invalidate: (result) ->
    result.view.classList.add 'invalid'
    result.invalid = true

  validate: (result) ->
    result.view.classList.remove 'invalid'
    result.invalid = false

  text: ({editor, marker}) ->
    editor.getTextInRange(marker.getBufferRange()).trim()

  watchText: (r) ->
    r.editWatch = r.editor.onDidChange => @checkText r

  checkText: (r) ->
    text = @text r
    if r.text == text and r.invalid then r.validate()
    else if r.text != text and !r.invalid then r.invalidate()

  watchNewline: (r) ->
    r.newlineWatch = r.marker.onDidChange (e) => @checkNewline r, e

  checkNewline: (r, e) ->
    if !e.isValid or r.marker.getBufferRange().isEmpty()
      r.destroy()
    else if e.textChanged
      old = e.oldHeadScreenPosition
      nu = e.newHeadScreenPosition
      text = r.editor.getTextInRange([old, nu])
      if old.isLessThan(nu) && text.match /^\r?\n\s*$/
        r.marker.setHeadBufferPosition old

  forLines: (ed, start, end) ->
    ed.findMarkers().filter((m)->m.result? &&
                                 m.getBufferRange().intersectsRowRange(start, end))
                    .map((m)->m.result)

  removeLines: (ed, start, end) ->
    flag = false
    for r in @forLines ed, start, end
      flag = true
      r.destroy()
    flag

  removeAll: (ed) ->
    ed ?= atom.workspace.getActiveTextEditor()
    for r in ed.findMarkers().filter((m)->m.result?).map((m)->m.result)
      r.destroy()
