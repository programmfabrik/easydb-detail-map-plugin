class MapDetailPlugin extends DetailSidebarPlugin

	@bigIconSize: 512
	@smallIconSize: 64
	@maxZoom: 18
	@minZoom: 0

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
			onClick: =>
				if @__markerSelected
					@__setIconToMarker(@__markerSelected, MapDetailPlugin.smallIconSize)
			onZoomEnd: =>
				@__onZoomEnd()

		CUI.Events.listen
			type: "viewport-resize"
			node: @_detailSidebar.mainPane
			call: =>
				@__map.resize()

		@__zoomButtons = @__getZoomButtons()
		@__zoomButtonbar = new CUI.Buttonbar(class: "ez5-detail-map-plugin-zoom-buttons", buttons: @__zoomButtons)
		@__zoomButtonbar.addButton(
			loca_key: "map.detail.plugin.fullscreen.open.button"
			group: "fullscreen"
			onClick: =>
				@__mapFullscreen = new MapFullscreen(
					map: @__map
					zoomButtons: @__zoomButtons
					onClose: =>
						@__onCloseFullscreen()
				)
				@__mapFullscreen.render()
				@__fullscreenActive = true
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
						cui_onClick: (event)=>
							marker = event.target
							@__markerOnClick(marker)

					if asset.value.versions.small
						options.icon = @__getDivIcon(asset.value.versions.small, MapDetailPlugin.smallIconSize)
						options.asset = asset

					markersOptions.push(options)

		markersOptions

	__getZoomButtons: ->
		[
			new LocaButton
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
			new LocaButton
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

	__onZoomEnd: ->
		zoomInButton = @__zoomButtons[0]
		zoomOutButton = @__zoomButtons[2]
		if @__map.getZoom() == MapDetailPlugin.maxZoom
			zoomInButton.disable()
		else
			zoomInButton.enable()

		if @__map.getZoom() == MapDetailPlugin.minZoom
			zoomOutButton.disable()
		else
			zoomOutButton.enable()

	__setIconToMarker: (marker, size) ->
		bigIcon = @__getDivIcon(marker.options.asset.value.versions.small, size)
		marker.setIcon(bigIcon)

	@getConfiguration: ->
		ez5.session.getBaseConfig().system["detail_map"] or {}

	@initMapbox: ->
		mapboxAttribution = 'Map data &copy; <a href="http://openstreetmap.org">OpenStreetMap</a> contributors, <a href="http://creativecommons.org/licenses/by-sa/2.0/">CC-BY-SA</a>, Imagery © <a href="http://mapbox.com">Mapbox</a>'

		CUI.LeafletMap.defaults.tileLayerOptions.attribution = mapboxAttribution
		CUI.LeafletMap.defaults.tileLayerOptions.id = ez5.session.getPref("mapboxTilesId")
		CUI.LeafletMap.defaults.tileLayerOptions.accessToken = MapDetailPlugin.getConfiguration().mapboxToken
		CUI.LeafletMap.defaults.tileLayerUrl = 'https://api.tiles.mapbox.com/v4/{id}/{z}/{x}/{y}.png?access_token={accessToken}'

ez5.session_ready =>
	DetailSidebar.plugins.registerPlugin(MapDetailPlugin)

	if MapDetailPlugin.getConfiguration().tiles == "Mapbox"
		if not ez5.session.getPref("mapboxTilesId")
			ez5.session.setPref("mapboxTilesId", "mapbox.streets")

		MapDetailPlugin.initMapbox()