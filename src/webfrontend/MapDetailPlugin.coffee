class MapDetailPlugin extends DetailSidebarPlugin

	getButtonLocaKey: ->
		"map.detail.plugin.button"

	prefName: ->
		"detail_sidebar_show_map"

	isAvailable: ->
		assets = @_detailSidebar.object.getAssetsForBrowser("detail")
		return assets and assets.length > 0

	isDisabled: ->
		markersOptions = @__getMarkerOptions()
		markersOptions.length == 0

	hideDetail: ->
		@_detailSidebar.mainPane.empty("top")

	renderObject: ->
		if @__map
			@__map.destroy()
		markersOptions = @__getMarkerOptions()
		if markersOptions.length == 0
			return

		@__map = new CUI.LeafletMap(
			class: "ez5-map-detail-plugin"
			clickable: false,
			markersOptions: markersOptions,
			zoomToFitAllMarkersOnInit: true,
			zoomControl: false)
		@__zoomButtonbar = @__buildZoomButtonbar()

	showDetail: ->
		if not @__map
			return
		@_detailSidebar.mainPane.replace([@__zoomButtonbar, @__map], "top")

	__getMarkerOptions: ->
		assets = @_detailSidebar.object.getAssetsForBrowser("detail")

		markersOptions = []
		for asset in assets
			gps_location = asset.value.technical_metadata.gps_location
			if gps_location and gps_location.latitude and gps_location.longitude
				do(asset) =>
					options =
						position:
							lat: gps_location.latitude,
							lng: gps_location.longitude
						cui_onClick: =>
							CUI.Events.trigger
								node: @_detailSidebar.container
								type: "asset-browser-show-asset"
								info:
									value: asset.value

					if asset.value.versions.small
						iconSize = ez5.fitRectangle(asset.value.versions.small.width, asset.value.versions.small.height, 30, 30)
						options.icon = L.icon(iconUrl: asset.value.versions.small.url, iconSize: iconSize)

					markersOptions.push(options)

		markersOptions

	__buildZoomButtonbar: ->
		new CUI.Buttonbar
			class: "cui-leaflet-map-zoom-buttons"
			buttons: [
				icon: "plus"
				group: "zoom"
				onClick: =>
					@__map.zoomIn()
			,
				icon: "minus"
				group: "zoom"
				onClick: =>
					@__map.zoomOut()
			]

ez5.session_ready =>
	DetailSidebar.plugins.registerPlugin(MapDetailPlugin)