class Panel extends KDView

  constructor: (options = {}, data) ->

    options.cssClass = KD.utils.curry "panel", options.cssClass

    super options, data

    @panesContainer = []
    @panes          = []
    @panesByName    = {}

    @createLayout()

  createLayout: ->
    {layoutOptions}  = @getOptions()
    unless layoutOptions
      return new Error "You should pass layoutOptions to create a panel"

    @layout = new WorkspaceLayoutBuilder { delegate: this, layoutOptions }
    @addSubView @layout

  createPane: (paneOptions) ->
    PaneClass = @getPaneClass paneOptions
    pane      = new PaneClass paneOptions

    @panesByName[paneOptions.name] = pane  if paneOptions.name

    @panes.push pane
    @emit "NewPaneCreated", pane
    return pane

  getPaneClass: (paneOptions) ->
    paneType  = paneOptions.type
    PaneClass = if paneType is "custom" then paneOptions.paneClass else @findPaneClass paneType

    unless PaneClass
      return new Error "PaneClass is not defined for \"#{paneOptions.type}\" pane type"

    return PaneClass

  findPaneClass: (paneType) ->
    paneTypesToPaneClass =
      terminal           : @TerminalPaneClass
      editor             : @EditorPaneClass
      video              : @VideoPaneClass
      preview            : @PreviewPaneClass
      finder             : @FinderPaneClass
      tabbedEditor       : @TabbedEditorPaneClass
      drawing            : @DrawingPaneClass

    return paneTypesToPaneClass[paneType]

  getPaneByName: (name) ->
    return @panesByName[name] or null

  EditorPaneClass       : KDView # EditorPane
  TabbedEditorPaneClass : KDView # EditorPane
  TerminalPaneClass     : KDView # TerminalPane
  VideoPaneClass        : KDView # VideoPane
  PreviewPaneClass      : KDView # PreviewPane
  DrawingPaneClass      : KDView # KDView
