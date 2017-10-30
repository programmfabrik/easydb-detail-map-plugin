class MapDetailPlugin extends DetailSidebarPlugin

	getButtonLocaKey: ->
		"map.detail.plugin.button"

	prefName: ->
		"detail_sidebar_show_map"

	isAvailable: ->
		if not @__getConfiguration().enabled
			return false

		assets = @_detailSidebar.object.getAssetsForBrowser("detail")
		return assets and assets.length > 0 and @__existsAtLeastOneAssetEnabledByCustomSettings(assets)

	isDisabled: ->
		markersOptions = @__getMarkerOptions()
		markersOptions.length == 0

	hideDetail: ->
		@_detailSidebar.mainPane.empty("top")

	renderObject: ->
		if @__map
			@__map.destroy()
			@__mapFullscreen?.destroy()
		markersOptions = @__getMarkerOptions()
		if markersOptions.length == 0
			return

		@__map = new CUI.LeafletMap
			class: "ez5-detail-map-plugin"
			clickable: false,
			markersOptions: markersOptions,
			zoomToFitAllMarkersOnInit: true,
			zoomControl: false

		zoomButtons = @__getZoomButtons()
		@__zoomButtonbar = new CUI.Buttonbar(class: "ez5-detail-map-plugin-zoom-buttons", buttons: zoomButtons)
		@__zoomButtonbar.addButton(
			loca_key: "map.detail.plugin.fullscreen.open.button"
			group: "fullscreen"
			onClick: =>
				@__mapFullscreen = new MapFullscreen(
					map: @__map
					zoomButtons: zoomButtons
					onClose: =>
						@showDetail()
						@__map.resize()
				)
				@__mapFullscreen.render()
		)

	showDetail: ->
		if not @__map
			return
		@_detailSidebar.mainPane.replace([@__zoomButtonbar, @__map], "top")

	__getMarkerOptions: ->
		assets = @_detailSidebar.object.getAssetsForBrowser("detail")

		markersOptions = []
		for asset in assets
			if not @__isAssetEnabledByCustomSetting(asset)
				continue

			gps_location = asset.value.technical_metadata.gps_location
			if gps_location and gps_location.latitude and gps_location.longitude
				do(asset) =>
					options =
						position:
							lat: gps_location.latitude,
							lng: gps_location.longitude
						cui_onClick: =>
							@__mapFullscreen?.close()
							CUI.Events.trigger
								node: @_detailSidebar.container
								type: "asset-browser-show-asset"
								info:
									value: asset.value

					if asset.value.versions.small
						options.icon = @__getDivIcon(asset.value.versions.small)

					markersOptions.push(options)

		markersOptions

	__getZoomButtons: ->
		[
			loca_key: "map.detail.plugin.zoom.plus.button"
			group: "zoom"
			onClick: =>
				@__map.zoomIn()
		,
			loca_key: "map.detail.plugin.zoom.reset.button"
			group: "zoom"
			onClick: =>
				@__map.zoomToFitAllMarkers()
		,
			loca_key: "map.detail.plugin.zoom.minus.button"
			group: "zoom"
			onClick: =>
				@__map.zoomOut()
		]

	__existsAtLeastOneAssetEnabledByCustomSettings: (assets) ->
		for asset in assets
			if @__isAssetEnabledByCustomSetting(asset)
				return true
		return false

	__isAssetEnabledByCustomSetting: (asset) ->
		showInMapSetting = asset.getField().FieldSchema.custom_settings.show_in_map
		return CUI.util.isNull(showInMapSetting) or showInMapSetting

	__getDivIcon: (image) ->
		[width, height] = ez5.fitRectangle(image.width, image.height, 64, 64)
		padding = 3 # from css
		pointerHeight = 7 # from css

		iconWidth = width + 2 * padding
		iconHeight = Math.round(height + 2 * padding + pointerHeight)

		# dx and dy are the top left offset of the pointer end
		iconAnchorOffsetX = Math.floor(iconWidth / 2)

		divIcon = L.divIcon(
			html: """<div class="ez5-map-marker">
									<img class="ez5-map-marker-image" src="#{ image.url }" style="width: #{ width }px; height: #{ height }px">
							 		<div class="ez5-map-marker-pointer"></div>
							 </div>
						"""
			iconAnchor: [iconAnchorOffsetX, iconHeight]
			iconSize: [iconWidth, iconHeight]
		)
		return divIcon

	__getConfiguration: ->
		ez5.session.getBaseConfig().system["detail_map"] or {}

ez5.session_ready =>
	DetailSidebar.plugins.registerPlugin(MapDetailPlugin)