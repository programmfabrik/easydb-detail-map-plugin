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
		customLocationMarkerOptions = @__getCustomLocationMarkerOptions()
		return assetMarkerOptions.length == 0 and customLocationMarkerOptions.length == 0

	hideDetail: ->
		@_detailSidebar.mainPane.empty("top")

	renderObject: ->
		if @__map
			@resetMap()

		assetMarkerOptions = @__getAssetMarkerOptions()
		customLocationMarkerOptions = @__getCustomLocationMarkerOptions()
		markerOptions = assetMarkerOptions.concat(customLocationMarkerOptions)

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

			gps_location = asset.value.technical_metadata.gps_location
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

					if asset.value.versions.small
						options.icon = @__getDivIcon(asset.value.versions.small, MapDetailPlugin.smallIconSize)
						options.asset = asset

					assetMarkerOptions.push(options)

		assetMarkerOptions

	__getCustomLocationMarkerOptions: ->
		customLocationMarkerOptions = []

		addToLocationsArray = (data) =>
			mapPosition = data.mapPosition
			customLocationMarkerOptions.push(
				position: mapPosition.position
				iconColor: mapPosition.iconColor
				iconName: mapPosition.iconName
				group: data.group
				cui_onClick: (event)	=>
					marker = event.target
					markerIcon = event.originalEvent.target
					@__customLocationMarkerOnClick(marker, markerIcon, data)
				cui_onDoubleClick: (event) =>
					marker = event.target
					@__map.setCenter(marker.getLatLng(), CUI.Map.defaults.maxZoom)
			)

		if @__isCustomDataTypeLocationEnabled()
			customDataArray = @_detailSidebar.object.getCustomDataTypeFields("detail", CustomDataTypeLocation)
			for customData in customDataArray
				if CUI.isArray(customData)
					for data in customData
						addToLocationsArray(data)
				else
					addToLocationsArray(customData)
		return customLocationMarkerOptions

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
		if @__isCustomDataTypeLocationEnabled()
			positions = @_detailSidebar.object.getCustomDataTypeFields("detail", CustomDataTypeLocation)

		assets = @_detailSidebar.object.getAssetsForBrowser("detail")
		isAvailableByAssets = assets and assets.length > 0 and @__existsAtLeastOneAssetEnabledByCustomSettings(assets)
		isAvailableByCustomDataTypeLocations = positions && positions.length > 0
		return isAvailableByAssets or isAvailableByCustomDataTypeLocations

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
			eventType = "location-marker-fullscreen-clicked"
			info.icon = markerIcon
		else
			eventType = "location-marker-clicked"

		CUI.Events.trigger
			node: @_detailSidebar.container
			type: eventType
			info: info

	__onCloseFullscreen: ->
		if @__markerSelected
			@__setIconToMarker(@__markerSelected, MapDetailPlugin.smallIconSize)
		@showDetail()

	__setIconToMarker: (marker, size) ->
		versions = marker.options.asset.value.versions
		imageVersion = if (size > 200 and versions.preview) then versions.preview else versions.small
		icon = @__getDivIcon(imageVersion, size)
		marker.setIcon(icon)

	__reload: ->
		MapDetailPlugin.initMapbox()
		@renderObject()
		@showDetail()

	__isCustomDataTypeLocationEnabled: ->
		isUnknownCustomDataType = CustomDataType.get("custom:base.custom-data-type-location.location") instanceof CustomDataTypeUnknown
		return not isUnknownCustomDataType

	__isFullscreen: ->
		return @__map.getFillScreenState()

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
	CUI.Events.registerEvent
		type: "map-detail-center"
		sink: true