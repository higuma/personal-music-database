# class/instance common prefixes and hierarchies
TYPES = ['artist', 'release', 'track']
CHILDREN = artist: 'release', release: 'track', track: null

# classes / singleton instances by type
Models = {}         # model classes
Items = {}          # collection instances
ModelViews = {}     # Model view classes
ItemsViews = {}     # collection view (controller) instances
ItemsMenus = {}     # new/edit/delete dropdown menu view instances

# Model classes
MODEL_SPECS =
  artist:
    defaults:
      name: ''
    validate: (attrs) ->
      name = attrs.name
      return 'Artist name is empty.' if name == ''
      for item in Items['artist'].models
        if item != @ && item.get('name') == name
          return "Artist name \"#{name}\" already exists."
      return

  release:
    defaults:
      title: ''
      year: (new Date).getFullYear()
      artistId: null
    validate: (attrs) ->
      return 'Release title is empty.' if attrs.title == ''
      return 'Artist ID is not set.' unless attrs.artistId?

  track:
    defaults:
      number: '0'
      title: ''
      minutes: '0'
      seconds: '00'
      releaseId: null
    validate: (attrs) ->
      return 'Track title is empty.' if attrs.title == ''
      return 'Release ID is not set.' unless attrs.releaseId?

for type, spec of MODEL_SPECS
  Models[type] = Backbone.Model.extend(_.extend spec, type: type)

# Collection instances
SubCollection = Backbone.Collection.extend
  setOwner: (owner) ->
    return false if @owner == owner
    if (@owner = owner)?
      @localStorage = new Backbone.LocalStorage @localStorageKeyName()
      @fetch()
    else
      @reset()
    true

  localStorageKeyName: ->
    if @owner
      "#{@type}-#{@owner.id}"
    else
      @type

compareString = do ->
  RE_PRE = /^(?:THE|A)\s/
  RE_W = /\s/g
  (a, b, attr) ->
    a = a.get(attr).toUpperCase().replace(RE_PRE, '').replace(RE_W, '')
    b = b.get(attr).toUpperCase().replace(RE_PRE, '').replace(RE_W, '')
    if a < b
      -1
    else if a > b
      1
    else
      0

compareNumberAndString = (a, b, attrNum, attrStr) ->
  x = Number(a.get attrNum)
  y = Number(b.get attrNum)
  if x < y
    -1
  else if x > y
    1
  else
    compareString a, b, attrStr

COLLECTION_SPECS =
  artist:
    inherits: Backbone.Collection
    comparator: (a, b) -> compareString a, b, 'name'
    localStorage: new Backbone.LocalStorage 'artist'

  release:
    inherits: SubCollection
    comparator: (a, b) -> compareNumberAndString a, b, 'year', 'title'

  track:
    inherits: SubCollection
    comparator: (a, b) -> compareNumberAndString a, b, 'number', 'title'

for type, spec of COLLECTION_SPECS
  spec = _.extend spec,
    type: type
    model: Models[type]
  Items[type] = new (spec.inherits.extend spec)

# Model(singular) views (classes)
MODEL_VIEW_SPEC =
  tagName: 'li'
  className: 'width-max'

  render: -> @$el.html @template(@model.toJSON())

for type in TYPES
  ModelViews[type] = Backbone.View.extend _.extend MODEL_VIEW_SPEC,
    template: _.template $("#template-#{type}").html()

# Collection views (controllers)
CollectionView = Backbone.View.extend
  events:
    'click li': 'onSelectItem'

  initialize: (options) ->
    @parentView = options.parentView
    @parentView.childView = @ if @parentView?
    @setListen()
    @selected = null

  setListen: -> @listenTo @items, 'sync', @onSync

  stopListen: -> @stopListening @items

  render: ->
    @$el.empty()
    for item in @items.models
      view = new @view model: item
      view.render()
      view.$el.attr 'item-id', item.id
      view.$el.addClass('active') if item == @item
      @$el.append view.$el
    @

  onSelectItem: (event) ->
    $('.active', @el).removeClass 'active'
    $target = $ event.currentTarget
    $target.addClass 'active'
    itemId = $target.attr('item-id')
    @item = @items.get itemId
    @syncChildView()

  onSync: ->
    if @items.length > 0
      @item = @items.models[0] unless @item?
      ItemsMenus[@type].enable
        new: true
        edit: true
        delete: true
    else
      @item = null
      ItemsMenus[@type].enable
        new: !@parentView? || @items.owner?
        edit: false
        delete: false
    @render()
    @syncChildView()

  syncChildView: ->
    @childView.syncFromParent @item if @childView?

  syncFromParent: (owner) ->
    return if owner == @items.owner
    @item = null
    if @items.setOwner owner
      @onSync() unless owner?

  onUpdate: (@item) ->
    @items.sort()
    @onSync()

  onDelete: (index) ->
    length = @items.length
    if length > 0
      index = length - 1 if index >= length
      @item = @items.models[index]
    @onSync()

parentView = null
for type in TYPES
  klass = CollectionView.extend
    type: type
    el: "#list-#{type}"
    items: Items[type]
    view: ModelViews[type]
  parentView = ItemsViews[type] = new klass parentView: parentView

# Modal action views (instances)
ModalEdit = Backbone.View.extend
  template: _.template $('#template-validation-error').html()

  events:
    'click .btn-primary': 'apply'

  titleMessage:
    create: 'New'
    update: 'Edit'

  applyMessage:
    create: 'Create'
    update: 'Update'

  initialize: ->
    @controls = @controls() if $.type(@controls) == 'function'

  show: (@item) ->
    if @item?
      @mode = 'update'
      data = @item.attributes
    else
      @mode = 'create'
      data = @defaults
    @renderAlert()
    $('.modal-title', @el).html "#{@titleMessage[@mode]} #{@type}"
    $('.btn-primary', @el).html @applyMessage[@mode]
    for attr in @attributes
      @controls[attr].val data[attr]
    @$el.modal 'show'

  apply: (event) ->
    data = {}
    for attr in @attributes
      data[attr] = @controls[attr].val()
    switch @mode
      when 'create'
        items = Items[@type]
        owner = items.owner
        if owner?
          data["#{owner.type}Id"] = owner.id
        item = Items[@type].create data, wait: true
        if item.validationError?
          @renderAlert item
          item.destroy()
          return
      when 'update'
        return @renderAlert @item unless @item.save data
    ItemsViews[@type].onUpdate @item
    @$el.modal 'hide'

  renderAlert: (item) ->
    $('.alert-dismissible', @el).remove()
    $('.modal-body', @el).prepend @template(item) if item?

MODAL_EDIT_SPECS =
  artist:
    attributes: ['name']

    defaults:
      name: ''

    controls: ->
      name: $ 'input[name="name"]', @el

  release:
    attributes: ['title', 'year']

    defaults:
      title: ''
      year: (new Date).getFullYear()

    controls: ->
      title: $ 'input[name="title"]', @el
      year: $ 'select[name="year"]', @el

  track:
    attributes: ['number', 'title', 'minutes', 'seconds']

    defaults:
        number: '0'
        title: ''
        minutes: '0'
        seconds: '00'

    controls: ->
      number: $ 'select[name="number"]', @el
      title: $ 'input[name="title"]', @el
      minutes: $ 'select[name="minutes"]', @el
      seconds: $ 'select[name="seconds"]', @el

ModalEditViews = {}     # new/edit modal view instances
for type, spec of MODAL_EDIT_SPECS
  spec = _.extend spec,
    el: "#modal-edit-#{type}"
    type: type
  ModalEditViews[type] = new (ModalEdit.extend spec)

NAME_ATTRS =
  artist: 'name'
  release: 'title'
  track: 'title'

ModalDeleteView = do -> # delete modal view instance
  klass = Backbone.View.extend
    el: '#modal-delete'

    events:
      'click .btn-primary': 'apply'

    show: (@type, @item) ->
      $('.modal-title', @el).html "Delete #{@type} - #{@item.get NAME_ATTRS[@type]}"
      $('.modal-body', @el).html "Are you sure?"
      @$el.modal 'show'

    apply: ->
      index = Items[@type].indexOf @item
      Commands.clearItem @item
      ItemsViews[@type].onDelete index
      @$el.modal 'hide'

  new klass

# Menu command modal view instances
ModalMenuCommandViews = {}
for action in ['load-sample-data', 'clear-data', 'startup']
  klass = Backbone.View.extend
    el: "#modal-#{action}"

    events:
      'click .btn-primary': 'apply'

    show: (@callback) ->
      @$el.modal 'show'

    apply: ->
      $('body').addClass 'cursor-wait'      # doesn't work (but keep it)
      $('.btn-primary', @el).button 'loading'
      @callback @
      @$el.modal 'hide'

    resetButton: ->
      $('body').removeClass 'cursor-wait'   # doesn't work also
      $('.btn-primary', @el).button 'reset'

  ModalMenuCommandViews[action] = new klass

# Header menus
CollectionMenu = Backbone.View.extend
  events:
    'click li': 'onMenu'

  onMenu: (event) ->
    li = $ event.currentTarget
    return if li.hasClass 'disabled'
    switch li.attr 'action'
      when 'new' then ModalEditViews[@type].show()
      when 'edit' then ModalEditViews[@type].show @controller.item
      when 'delete' then ModalDeleteView.show @type, @controller.item

  enable: (actions) ->
    for action, ena of actions
      $("li[action='#{action}']", @el).toggleClass 'disabled', !ena

for type in TYPES
  klass = CollectionMenu.extend
    el: "#menu-#{type}"
    controller: ItemsViews[type]
    type: type
  ItemsMenus[type] = new klass

# Navbar menu
NavbarMenu = do ->
  klass = Backbone.View.extend
    el: '#navbar-menu'

    events:
      'click li': 'onMenu'

    onMenu: (event) ->
      action = $(event.currentTarget).attr 'action'
      callback = switch action
        when 'load-sample-data' then Commands.loadSampleData
        when 'clear-data' then Commands.clearData
      ModalMenuCommandViews[action].show callback

  new klass

# Global utility commands
Commands = do ->
  clearItem = (item) ->
    if (childType = CHILDREN[item.type])?
      childItems = Items[childType]
      childItems.setOwner item
      clearItems childItems
    item.destroy()

  clearItems = (items) ->
    clearItem items.models[0] while items.length > 0
    storage = items.localStorage
    storage.localStorage().removeItem(storage.name)

  clearAll = ->
    clearItems Items['artist']

  refreshAll = (modalView) ->
    modalView.resetButton()
    ItemsViews['artist'].item = null
    ItemsViews['artist'].onSync()

  setListen = -> ItemsViews[type].setListen() for type in TYPES

  stopListen = -> ItemsViews[type].stopListen() for type in TYPES

  clearData = (modalView) ->
    stopListen()
    clearAll()
    setListen()
    refreshAll modalView

  loadSampleData = (modalView) ->
    stopListen()
    clearAll()
    $.getJSON 'data/data.json', (data) ->
      artists = Items['artist']
      releases = Items['release']
      tracks = Items['track']
      for album in data
        unless (artist = artists.findWhere name: album.artist)?
          artist = artists.create name: album.artist
        releases.setOwner artist
        release = releases.create
          title: album.title
          year: album.year
          artistId: artist.id
        tracks.setOwner release
        for number, trackInfo of album.tracks
          [trackTitle, duration] = trackInfo
          [minutes, seconds] = duration.split ':'
          tracks.create
            number: number
            title: trackTitle
            minutes: minutes
            seconds: seconds
            releaseId: release.id
      setListen()
      refreshAll modalView

  clearItem: clearItem
  clearItems: clearItems
  clearData: clearData
  loadSampleData: loadSampleData

# start application
Items['artist'].fetch().done ->
  if Items['artist'].length == 0
    ModalMenuCommandViews['startup'].show Commands.loadSampleData
