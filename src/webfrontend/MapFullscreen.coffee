class MapFullscreen extends CUI.DOMElement

	initOpts: ->
		super()
		@addOpts
			map:
				check: CUI.LeafletMap
			menuButton:
				check: CUI.Button
			onClose:
				check: Function

	constructor: (@opts = {}) ->
		super(@opts)
		@registerDOMElement(CUI.dom.div())
		@addClass("ez5-detail-map-plugin-fullscreen")

		@__closeFullScreenButton =
			loca_key: "map.detail.plugin.fullscreen.close.button"
			group: "rightButtonbar"
			onClick: =>
				@close()

	render: ->
		buttons = [@__closeFullScreenButton]
		if @_menuButton
			buttons.push(@_menuButton)

		CUI.dom.append(@DOM, @_map)

		@_map.setButtonBar(buttons, "upper-right")

		document.body.appendChild(@DOM)
		@_map.resize()

	close: ->
		document.body.removeChild(@DOM)
		@_onClose?()