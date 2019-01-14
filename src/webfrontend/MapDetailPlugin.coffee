class MapDetailPlugin extends DetailSidebarPlugin

	@bigIconSize: 320
	@smallIconSize: 64
	@mapboxTilesetStreets:
		name: "mapbox.streets"
		maxZoom: 18
	@mapboxTilesetStreetsEnglish:
		name: "mapbox.run-bike-hike"
		maxZoom: 18
	@mapboxTilesetSatellite:
		name: "mapbox.satellite"
		maxZoom: 12

	getButtonLocaKey: ->
		"map.detail.plugin.button"

	prefName: ->
		"detail_sidebar_show_map"

	isAvailable: ->
		return MapDetailPlugin.getConfiguration().enabled and @__areMarkersAvailable()

	isDisabled: ->
		assetMarkerOptions = @__getAssetMarkerOptions()
		isPluginSupportedByOtherFields = @_detailSidebar.object.isPluginSupported(@, "detail")
		return assetMarkerOptions.length == 0 and not isPluginSupportedByOtherFields

	hideDetail: ->
		@_detailSidebar.mainPane.empty("top")

	renderObject: ->
		if @__map
			@resetMap()

		@__addLocationTriggered = false
		markerOptions = @__getAssetMarkerOptions()

		@__menuButton = @__getMenuButton()
		@__buttonsUpperRight = if @__menuButton then [@__menuButton] else []

		@__map = @__buildMap(markerOptions)

		CUI.Events.listen
			type: "map-detail-center"
			node: @_detailSidebar.container
			instance: @
			call: (_, position) =>
				if CUI.Map.isValidPosition(position)
					if not @getButton().isActive()
						@getButton().activate()

					if @__isMapReady
						@__map.setCenter(position, CUI.Map.defaults.maxZoom)
					else
						@__initCenter = position

		CUI.Events.listen
			type: "end-fill-screen"
			node: @__map
			instance: @
			call: =>
				@__onCloseFullscreen()
		return

	showDetail: ->
		if not @__map
			return

		@_detailSidebar.mainPane.replace(@__map, "top")

	__buildMap: (markersOptions) ->
		new CUI.LeafletMap
			class: "ez5-detail-map-plugin"
			clickable: false,
			markersOptions: markersOptions,
			zoomToFitAllMarkersOnInit: true,
			buttonsUpperRight: @__buttonsUpperRight
			onClick: =>
				if @__markerSelected
					@__setIconToMarker(@__markerSelected, MapDetailPlugin.smallIconSize)
			onReady: =>
				@__isMapReady = true
				if @__initCenter
					@__map.setCenter(@__initCenter, CUI.Map.defaults.maxZoom)
					delete @__initCenter

	__getAssetMarkerOptions: ->
		assets = @_detailSidebar.object.getAssetsForBrowser("detail")

		assetMarkerOptions = []
		for asset in assets
			if not @__isAssetEnabledByCustomSetting(asset)
				continue

			if CUI.util.isEmpty(asset.value.versions)
				continue

			gps_location = asset.value.technical_metadata?.gps_location
			if gps_location and gps_location.latitude and gps_location.longitude
				do(asset) =>
					options =
						position:
							lat: gps_location.latitude,
							lng: gps_location.longitude
						cui_onClick: (event) =>
							marker = event.target
							@__assetMarkerOnClick(marker)
						cui_onDoubleClick: (event) =>
							marker = event.target
							@__map.setCenter(marker.getLatLng(), CUI.Map.defaults.maxZoom)

					if asset.value.versions.small and asset.value.versions.small.width > 0 and asset.value.versions.small.height > 0
						options.icon = @__getDivIcon(asset.value.versions.small, MapDetailPlugin.smallIconSize)
						options.asset = asset

					assetMarkerOptions.push(options)

		assetMarkerOptions

	__addMarker: (data) =>
		if not MapDetailPlugin.getConfiguration().enabled
			return

		location =
			position: data.position
			iconColor: data.iconColor
			iconName: data.iconName
			group: data.group
			cui_onClick: (event)	=>
				marker = event.target
				markerIcon = event.originalEvent.target
				@__customLocationMarkerOnClick(marker, markerIcon, data)
			cui_onDoubleClick: (event) =>
				marker = event.target
				@__map.setCenter(marker.getLatLng(), CUI.Map.defaults.maxZoom)

		@__map.addMarker(location)
		return

	__getMenuButton: ->
		if MapDetailPlugin.getConfiguration().tiles == "Mapbox"
			new LocaButton
				loca_key: "map.detail.plugin.menu.button"
				icon_right: false
				group: "upper-right"
				menu:
					items: @__getMenuItems()

	__getMenuItems: ->
		currentTilesetName = ez5.session.getPref("mapboxTilesetOptions").name

		return [
				new LocaLabel
					loca_key: "map.detail.plugin.menu.language.label"
			,
				text: $$("map.detail.plugin.menu.language.english.label")
				active: currentTilesetName == MapDetailPlugin.mapboxTilesetStreetsEnglish.name
				disabled: currentTilesetName == MapDetailPlugin.mapboxTilesetSatellite.name
				onClick: =>
					ez5.session.savePref("mapboxTilesetOptions", MapDetailPlugin.mapboxTilesetStreetsEnglish)
					@__reload()
			,
				text: $$("map.detail.plugin.menu.language.local.label")
				active: currentTilesetName == MapDetailPlugin.mapboxTilesetStreets.name || currentTilesetName == MapDetailPlugin.mapboxTilesetSatellite.name
				onClick: =>
					if currentTilesetName != MapDetailPlugin.mapboxTilesetSatellite.name
						ez5.session.savePref("mapboxTilesetOptions", MapDetailPlugin.mapboxTilesetStreets)
						@__reload()
			,
				new LocaLabel
					loca_key: "map.detail.plugin.menu.tileset.label"
			,
				text: $$("map.detail.plugin.menu.tileset.street.label")
				active: currentTilesetName == MapDetailPlugin.mapboxTilesetStreets.name || currentTilesetName == MapDetailPlugin.mapboxTilesetStreetsEnglish.name
				onClick: =>
					ez5.session.savePref("mapboxTilesetOptions", MapDetailPlugin.mapboxTilesetStreets)
					@__reload()
			,
				text: $$("map.detail.plugin.menu.tileset.satellite.label")
				active: currentTilesetName == MapDetailPlugin.mapboxTilesetSatellite.name
				onClick: =>
					ez5.session.savePref("mapboxTilesetOptions", MapDetailPlugin.mapboxTilesetSatellite)
					@__reload()
		]

	__areMarkersAvailable: ->
		assets = @_detailSidebar.object.getAssetsForBrowser("detail")
		isPluginSupportedByOtherFields = @_detailSidebar.object.isPluginSupported(@, "detail")
		isAvailableByAssets = assets and assets.length > 0 and @__existsAtLeastOneAssetEnabledByCustomSettings(assets)
		return isAvailableByAssets or isPluginSupportedByOtherFields

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

	__assetMarkerOnClick: (marker) ->
		if not marker.options.asset?.value
			return

		if @__isFullscreen()
			# TODO: Show more asset information.
			if @__markerSelected
				@__setIconToMarker(@__markerSelected, MapDetailPlugin.smallIconSize)

				if @__markerSelected == marker
					@__markerSelected = null
					return

			@__setIconToMarker(marker, MapDetailPlugin.bigIconSize)
			@__markerSelected = marker
		else
			CUI.Events.trigger
				node: @_detailSidebar.container
				type: "asset-browser-show-asset"
				info:
					value: marker.options.asset.value

	__customLocationMarkerOnClick: (marker, markerIcon, data) ->
		info = data: data
		if @__isFullscreen()
			eventType = "map-detail-fullscreen-click-location"
			info.icon = markerIcon
		else
			eventType = "map-detail-click-location"

		CUI.Events.trigger
			node: @_detailSidebar.container
			type: eventType
			info: info

	__onCloseFullscreen: ->
		if @__markerSelected
			@__setIconToMarker(@__markerSelected, MapDetailPlugin.smallIconSize)
		@showDetail()

	__setIconToMarker: (marker, size) ->
		assetValue = marker.options.asset.value
		versionName = Asset.getStandardVersionName(assetValue)
		imageVersion = assetValue.versions[versionName]
		icon = @__getDivIcon(imageVersion, size)
		marker.setIcon(icon)

	__reload: ->
		MapDetailPlugin.initMapbox()
		@renderObject()
		@showDetail()

	__isFullscreen: ->
		return @__map.getFillScreenState()

	addMarker: (data) ->
		if CUI.isArray(data)
			for _data in data
				if _data
					@__addMarker(_data)
		else
			@__addMarker(data)

	resetMap: ->
		@__map?.destroy()
		delete @__map
		delete @__isMapReady

		@__menuButton?.destroy()
		delete @__menuButton

		delete @__markerSelected
		delete @__buttonsUpperRight
		delete @__initCenter

		CUI.Events.ignore(instance: @)
		return

	destroy: ->
		@resetMap()
		super()

	@getConfiguration: ->
		ez5.session.getBaseConfig().system["detail_map"] or {}

	@initMapbox: ->
		mapboxAttribution = 'Map data &copy; <a href="http://openstreetmap.org">OpenStreetMap</a> contributors, <a href="http://creativecommons.org/licenses/by-sa/2.0/">CC-BY-SA</a>, Imagery © <a href="http://mapbox.com">Mapbox</a>'

		mapboxTileset = ez5.session.getPref("mapboxTilesetOptions") or MapDetailPlugin.mapboxTilesetStreets
		CUI.Map.defaults.maxZoom = mapboxTileset.maxZoom

		CUI.LeafletMap.defaults.tileLayerOptions.attribution = mapboxAttribution
		CUI.LeafletMap.defaults.tileLayerOptions.id = mapboxTileset.name
		CUI.LeafletMap.defaults.tileLayerOptions.accessToken = MapDetailPlugin.getConfiguration().mapboxToken
		CUI.LeafletMap.defaults.tileLayerUrl = 'https://api.tiles.mapbox.com/v4/{id}/{z}/{x}/{y}.png?access_token={accessToken}'

ez5.session_ready ->
	DetailSidebar.plugins.registerPlugin(MapDetailPlugin)

	if MapDetailPlugin.getConfiguration().tiles == "Mapbox"
		ez5.session.addCookieOnlyPref("mapboxTilesetOptions", MapDetailPlugin.mapboxTilesetStreets)

		MapDetailPlugin.initMapbox()

CUI.ready ->
	# The map will be centered if this event is triggered.
	CUI.Events.registerEvent
		type: "map-detail-center"
		sink: true

	# This event will be triggered by the map if the location is clicked.
	CUI.Events.registerEvent
		type: "map-detail-click-location"
		sink: true

	# This event will be triggered by the map if the location is clicked in fullscreen mode.
	CUI.Events.registerEvent
		type: "map-detail-fullscreen-click-location"
		sink: true