class MapDetailPlugin extends DetailSidebarPlugin

	@bigIconSize: 320
	@smallIconSize: 64
	@mapboxTilesetStreets: "mapbox.streets"
	@mapboxTilesetStreetsEnglish: "mapbox.run-bike-hike"
	@mapboxTilesetSatellite: "mapbox.satellite"

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
			@__destroyMap()

		assetMarkerOptions = @__getAssetMarkerOptions()
		customLocationMarkerOptions = @__getCustomLocationMarkerOptions()
		markerOptions = assetMarkerOptions.concat(customLocationMarkerOptions)

		@__menuButton = @__getMenuButton()
		@__buttonsUpperRight = [@__getFullScreenButton()]
		if @__menuButton
			@__buttonsUpperRight.push(@__menuButton)

		@__map = @__buildMap(markerOptions)

		@__mapFullscreen = new MapFullscreen(
			map: @__map
			menuButton: @__menuButton
			onClose: =>
				@__map.setButtonBar(@__buttonsUpperRight, "upper-right")
				@__onCloseFullscreen()
		)

		@__mapDetailCenterListener = CUI.Events.listen
			type: "map-detail-center"
			node: @_detailSidebar.container
			call: (_, position) =>
				if CUI.Map.isValidPosition(position)
					if not @getButton().isActive()
						@getButton().activate()

					if @__isMapReady
						@__map.setCenter(position, CUI.Map.defaults.maxZoom)
					else
						@__initCenter = position

		@__viewportResizeListener = CUI.Events.listen
			type: "viewport-resize"
			node: @_detailSidebar.mainPane
			call: =>
				@__map?.resize()

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

			gps_location = asset.value.technical_metadata.gps_location
			if gps_location and gps_location.latitude and gps_location.longitude
				do(asset) =>
					options =
						position:
							lat: gps_location.latitude,
							lng: gps_location.longitude
						cui_onClick: (event)=>
							marker = event.target
							@__assetMarkerOnClick(marker)

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
					@__customLocationMarkerOnClick(marker, data)
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

	__getFullScreenButton: ->
		loca_key: "map.detail.plugin.fullscreen.open.button"
		group: "rightButtonbar"
		onClick: =>
			@__mapFullscreen.render()
			@__fullscreenActive = true

	__getMenuButton: ->
		if MapDetailPlugin.getConfiguration().tiles == "Mapbox"
			new LocaButton
				loca_key: "map.detail.plugin.menu.button"
				icon_right: false
				group: "rightButtonbar"
				menu:
					items: @__getMenuItems()

	__getMenuItems: ->
		currentTileset = ez5.session.getPref("map").mapboxTileset

		return [
				new LocaLabel
					loca_key: "map.detail.plugin.menu.language.label"
			,
				text: $$("map.detail.plugin.menu.language.english.label")
				active: currentTileset == MapDetailPlugin.mapboxTilesetStreetsEnglish
				disabled: currentTileset == MapDetailPlugin.mapboxTilesetSatellite
				onClick: =>
					ez5.session.savePref("map", mapboxTileset: MapDetailPlugin.mapboxTilesetStreetsEnglish)
					@__reload()
			,
				text: $$("map.detail.plugin.menu.language.local.label")
				active: currentTileset == MapDetailPlugin.mapboxTilesetStreets || currentTileset == MapDetailPlugin.mapboxTilesetSatellite
				onClick: =>
					if currentTileset != MapDetailPlugin.mapboxTilesetSatellite
						ez5.session.savePref("map", mapboxTileset: MapDetailPlugin.mapboxTilesetStreets)
						@__reload()
			,
				new LocaLabel
					loca_key: "map.detail.plugin.menu.tileset.label"
			,
				text: $$("map.detail.plugin.menu.tileset.street.label")
				active: currentTileset == MapDetailPlugin.mapboxTilesetStreets || currentTileset == MapDetailPlugin.mapboxTilesetStreetsEnglish
				onClick: =>
					ez5.session.savePref("map", mapboxTileset: MapDetailPlugin.mapboxTilesetStreets)
					@__reload()
			,
				text: $$("map.detail.plugin.menu.tileset.satellite.label")
				active: currentTileset == MapDetailPlugin.mapboxTilesetSatellite
				onClick: =>
					ez5.session.savePref("map", mapboxTileset: MapDetailPlugin.mapboxTilesetSatellite)
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
		if @__fullscreenActive
			if @__markerSelected
				@__setIconToMarker(@__markerSelected, MapDetailPlugin.smallIconSize)
			@__setIconToMarker(marker, MapDetailPlugin.bigIconSize)
			@__markerSelected = marker
		else
			if @__map.getZoom() == CUI.Map.defaults.maxZoom
				CUI.Events.trigger
					node: @_detailSidebar.container
					type: "asset-browser-show-asset"
					info:
						value: marker.options.asset.value
			else
				@__map.setCenter(marker.getLatLng(), CUI.Map.defaults.maxZoom)

	__customLocationMarkerOnClick: (marker, data) ->
		if @__map.getZoom() == CUI.Map.defaults.maxZoom
			CUI.Events.trigger
				node: @_detailSidebar.container
				type: "location-marker-clicked"
				info: data
		else
			@__map.setCenter(marker.getLatLng(), CUI.Map.defaults.maxZoom)

	__onCloseFullscreen: ->
		if @__markerSelected
			@__setIconToMarker(@__markerSelected, MapDetailPlugin.smallIconSize)
		@showDetail()
		@__map.resize()
		@__fullscreenActive = false

	__setIconToMarker: (marker, size) ->
		versions = marker.options.asset.value.versions
		imageVersion = if (size > 200 and versions.preview) then versions.preview else versions.small
		bigIcon = @__getDivIcon(imageVersion, size)
		marker.setIcon(bigIcon)

	__destroyMap: ->
		@__isMapReady = false
		@__map.destroy()
		@__mapFullscreen?.destroy()
		delete @__map

		@__mapDetailCenterListener.destroy()
		@__viewportResizeListener.destroy()

	__reload: ->
		MapDetailPlugin.initMapbox()
		@renderObject()
		@showDetail()

		if @__fullscreenActive
			@__mapFullscreen.render()

	__isCustomDataTypeLocationEnabled: ->
		isUnknownCustomDataType = CustomDataType.get("custom:base.custom-data-type-location.location") instanceof CustomDataTypeUnknown
		return not isUnknownCustomDataType

	@getConfiguration: ->
		ez5.session.getBaseConfig().system["detail_map"] or {}

	@initMapbox: ->
		mapboxAttribution = 'Map data &copy; <a href="http://openstreetmap.org">OpenStreetMap</a> contributors, <a href="http://creativecommons.org/licenses/by-sa/2.0/">CC-BY-SA</a>, Imagery © <a href="http://mapbox.com">Mapbox</a>'

		CUI.LeafletMap.defaults.tileLayerOptions.attribution = mapboxAttribution
		CUI.LeafletMap.defaults.tileLayerOptions.id = ez5.session.getPref("map").mapboxTileset
		CUI.LeafletMap.defaults.tileLayerOptions.accessToken = MapDetailPlugin.getConfiguration().mapboxToken
		CUI.LeafletMap.defaults.tileLayerUrl = 'https://api.tiles.mapbox.com/v4/{id}/{z}/{x}/{y}.png?access_token={accessToken}'

ez5.session_ready =>
	DetailSidebar.plugins.registerPlugin(MapDetailPlugin)

	CUI.Map.defaults.zoomButtons.plus.tooltip = $$("map.detail.plugin.zoom.plus.button|tooltip")
	CUI.Map.defaults.zoomButtons.reset.tooltip = $$("map.detail.plugin.zoom.reset.button|tooltip")
	CUI.Map.defaults.zoomButtons.minus.tooltip = $$("map.detail.plugin.zoom.minus.button|tooltip")

	if MapDetailPlugin.getConfiguration().tiles == "Mapbox"
		if not ez5.session.getPref("map").mapboxTileset
			ez5.session.savePref("map", mapboxTileset: MapDetailPlugin.mapboxTilesetStreets)

		MapDetailPlugin.initMapbox()

CUI.ready ->
	CUI.Events.registerEvent
		type: "map-detail-center"
		sink: true