class MapFullscreen extends CUI.DOMElement

	initOpts: ->
		super()
		@addOpts
			map:
				check: CUI.LeafletMap
			zoomButtons:
				check: Array
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
		buttonbar = new CUI.Buttonbar(class: "ez5-detail-map-plugin-zoom-buttons", buttons: @_zoomButtons)
		buttonbar.addButton(@__closeFullScreenButton)

		CUI.dom.append(@DOM, [buttonbar, @_map])
		document.body.appendChild(@DOM)
		@_map.resize()

	close: ->
		document.body.removeChild(@DOM)
		@_onClose?()