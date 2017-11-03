class MapDetailPlugin extends DetailSidebarPlugin

	@bigIconSize: 320
	@smallIconSize: 64
	@maxZoom: 18
	@minZoom: 0
	@mapboxTilesetStreets: "mapbox.streets"
	@mapboxTilesetSatellite: "mapbox.satellite"
	@mapboxLanguageLocale: "locale"
	@mapboxLanguageApplication: "aplication"

	CUI.LeafletMap.defaults.tileLayerOptions.maxZoom = MapDetailPlugin.maxZoom

	getButtonLocaKey: ->
		"map.detail.plugin.button"

	prefName: ->
		"detail_sidebar_show_map"

	isAvailable: ->
		if not MapDetailPlugin.getConfiguration().enabled
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
			@__destroyMap()

		markersOptions = @__getMarkerOptions()
		if markersOptions.length == 0
			return

		@__map = @__buildMap(markersOptions)
		@__zoomButtons = @__getZoomButtons()
		@__fullScreenButton = @__getFullScreenButton()
		if MapDetailPlugin.getConfiguration().tiles == "Mapbox"
			@__menuButton = @__getMenuButton()

		@__mapFullscreen = new MapFullscreen(
			map: @__map
			zoomButtons: @__zoomButtons
			onClose: =>
				@__onCloseFullscreen()
		)

		CUI.Events.listen
			type: "viewport-resize"
			node: @_detailSidebar.mainPane
			call: =>
				@__map?.resize()

	showDetail: ->
		if not @__map
			return

		buttonBar = new CUI.Buttonbar(class: "ez5-detail-map-plugin-zoom-buttons", buttons: @__zoomButtons)
		if @__menuButton
			buttonBar.addButton(@__menuButton)
		buttonBar.addButton(@__fullScreenButton)
		@_detailSidebar.mainPane.replace([buttonBar, @__map], "top")

	__buildMap: (markersOptions) ->
		new CUI.LeafletMap
			class: "ez5-detail-map-plugin"
			clickable: false,
			markersOptions: markersOptions,
			zoomToFitAllMarkersOnInit: true,
			zoomControl: false
			onClick: =>
				if @__markerSelected
					@__setIconToMarker(@__markerSelected, MapDetailPlugin.smallIconSize)
			onMoveEnd: =>
				@__disableEnableZoomButtons()
			onReady: =>
				@__initZoom = @__map.getZoom()
				@__initCenter = @__map.getCenter()
				@__disableEnableZoomButtons()

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
						cui_onClick: (event)=>
							marker = event.target
							@__markerOnClick(marker)

					if asset.value.versions.small
						options.icon = @__getDivIcon(asset.value.versions.small, MapDetailPlugin.smallIconSize)
						options.asset = asset

					markersOptions.push(options)

		markersOptions

	__getZoomButtons: ->
		return [
			new LocaButton
				loca_key: "map.detail.plugin.zoom.plus.button"
				group: "zoom"
				onClick: =>
					@__map.zoomIn()
		,
			new LocaButton
					loca_key: "map.detail.plugin.zoom.reset.button"
					group: "zoom"
					onClick: =>
						@__map.setCenter(@__initCenter, @__initZoom)
						@__disableEnableZoomButtons()
		,
			new LocaButton
					loca_key: "map.detail.plugin.zoom.minus.button"
					group: "zoom"
					onClick: =>
						@__map.zoomOut()
		]

	__getFullScreenButton: ->
		loca_key: "map.detail.plugin.fullscreen.open.button"
		group: "rightButtonbar"
		onClick: =>
			@__mapFullscreen.render()
			@__fullscreenActive = true

	__getMenuButton: ->
		new LocaButton
			loca_key: "map.detail.plugin.menu.button"
			icon_right: false
			group: "rightButtonbar"
			menu:
				items: @__getMenuItems()

	__getMenuItems: ->
		currentTileset = ez5.session.getPref("mapboxTileset")
		currentLanguage = ez5.session.getPref("mapboxLanguage")

		return [
			new LocaLabel
				loca_key: "map.detail.plugin.menu.language.label"
		,
			text: $$("map.detail.plugin.menu.language.application.label")
			active: currentLanguage == MapDetailPlugin.mapboxLanguageApplication
			onClick: =>
				ez5.session.setPref("mapboxLanguage", MapDetailPlugin.mapboxLanguageApplication)
				@__reload()
		,
			text: $$("map.detail.plugin.menu.language.locale.label")
			active: currentLanguage == MapDetailPlugin.mapboxLanguageLocale
			onClick: =>
				ez5.session.setPref("mapboxLanguage", MapDetailPlugin.mapboxLanguageLocale)
				@__reload()
		,
			new LocaLabel
				loca_key: "map.detail.plugin.menu.tileset.label"
		,
			text: $$("map.detail.plugin.menu.tileset.street.label")
			active: currentTileset == MapDetailPlugin.mapboxTilesetStreets
			onClick: =>
				ez5.session.setPref("mapboxTileset", MapDetailPlugin.mapboxTilesetStreets)
				@__reload()
		,
			text: $$("map.detail.plugin.menu.tileset.satellite.label")
			active: currentTileset == MapDetailPlugin.mapboxTilesetSatellite
			onClick: =>
				ez5.session.setPref("mapboxTileset", MapDetailPlugin.mapboxTilesetSatellite)
				@__reload()
		]

	__existsAtLeastOneAssetEnabledByCustomSettings: (assets) ->
		for asset in assets
			if @__isAssetEnabledByCustomSetting(asset)
				return true
		return false

	__isAssetEnabledByCustomSetting: (asset) ->
		showInMapSetting = asset.getField().FieldSchema.custom_settings.show_in_map
		return CUI.util.isNull(showInMapSetting) or showInMapSetting

	__getDivIcon: (image, size) ->
		[width, height] = ez5.fitRectangle(image.width, image.height, size, size)
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
			className: "ez5-leaflet-div-icon"
			iconAnchor: [iconAnchorOffsetX, iconHeight]
			iconSize: [iconWidth, iconHeight]
		)
		return divIcon

	__markerOnClick: (marker) ->
		if @__fullscreenActive
			if @__markerSelected
				@__setIconToMarker(@__markerSelected, MapDetailPlugin.smallIconSize)
			@__setIconToMarker(marker, MapDetailPlugin.bigIconSize)
			@__markerSelected = marker
		else
			if @__map.getZoom() == MapDetailPlugin.maxZoom
				CUI.Events.trigger
					node: @_detailSidebar.container
					type: "asset-browser-show-asset"
					info:
						value: marker.options.asset.value
			else
				@__map.setCenter(marker.getLatLng(), MapDetailPlugin.maxZoom)

	__onCloseFullscreen: ->
		if @__markerSelected
			@__setIconToMarker(@__markerSelected, MapDetailPlugin.smallIconSize)
		@showDetail()
		@__map.resize()
		@__fullscreenActive = false

	__disableEnableZoomButtons: ->
		zoomInButton = @__zoomButtons[0]
		centerButton = @__zoomButtons[1]
		zoomOutButton = @__zoomButtons[2]
		if @__map.getZoom() == MapDetailPlugin.maxZoom
			zoomInButton.disable()
		else
			zoomInButton.enable()

		if @__map.getZoom() == MapDetailPlugin.minZoom
			zoomOutButton.disable()
		else
			zoomOutButton.enable()

		currentCenter = @__map.getCenter()
		if @__map.getZoom() == @__initZoom and Math.round(currentCenter.lat) == Math.round(@__initCenter.lat) and Math.round(currentCenter.lng) == Math.round(@__initCenter.lng)
			centerButton.disable()
		else
			centerButton.enable()

	__setIconToMarker: (marker, size) ->
		versions = marker.options.asset.value.versions
		imageVersion = if (size > 200 and versions.preview) then versions.preview else versions.small
		bigIcon = @__getDivIcon(imageVersion, size)
		marker.setIcon(bigIcon)

	__destroyMap: ->
		@__map.destroy()
		@__mapFullscreen?.destroy()
		delete @__map

	__reload: ->
		MapDetailPlugin.initMapbox()
		@renderObject()
		@showDetail()

	@getConfiguration: ->
		ez5.session.getBaseConfig().system["detail_map"] or {}

	@initMapbox: ->
		mapboxAttribution = 'Map data &copy; <a href="http://openstreetmap.org">OpenStreetMap</a> contributors, <a href="http://creativecommons.org/licenses/by-sa/2.0/">CC-BY-SA</a>, Imagery © <a href="http://mapbox.com">Mapbox</a>'

		CUI.LeafletMap.defaults.tileLayerOptions.attribution = mapboxAttribution
		CUI.LeafletMap.defaults.tileLayerOptions.id = ez5.session.getPref("mapboxTileset")
		CUI.LeafletMap.defaults.tileLayerOptions.accessToken = MapDetailPlugin.getConfiguration().mapboxToken
		CUI.LeafletMap.defaults.tileLayerUrl = 'https://api.tiles.mapbox.com/v4/{id}/{z}/{x}/{y}.png?access_token={accessToken}'

ez5.session_ready =>
	DetailSidebar.plugins.registerPlugin(MapDetailPlugin)

	if MapDetailPlugin.getConfiguration().tiles == "Mapbox"
		if not ez5.session.getPref("mapboxTileset")
			ez5.session.setPref("mapboxTileset", MapDetailPlugin.mapboxTilesetStreets)
		if not ez5.session.getPref("mapboxLanguage")
			ez5.session.setPref("mapboxLanguage", MapDetailPlugin.mapboxLanguageLocale)

		MapDetailPlugin.initMapbox()