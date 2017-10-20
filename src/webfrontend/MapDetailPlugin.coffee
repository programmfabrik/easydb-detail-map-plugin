class MapDetailPlugin extends DetailSidebarPlugin

	getButtonLocaKey: ->
		"map.detail.plugin.button"

	prefName: ->
		"detail_sidebar_show_map"

	isAvailable: ->
		true

	isDisabled: ->
		markersOptions = @__getMarkerOptions()
		markersOptions.length == 0

	hideDetail: ->
		@_detailSidebar.mainPane.empty("top")

	showDetail: ->
		markersOptions = @__getMarkerOptions()
		if markersOptions.length == 0
			return

		@__map = new CUI.LeafletMap(clickable: false, center: markersOptions[0].position, markersOptions: markersOptions)
		@_detailSidebar.mainPane.replace(@__map, "top")

	__getMarkerOptions: () ->
		assets = @_detailSidebar.object.getAssetsForBrowser("detail")

		markersOptions = []
		for asset in assets
			iconSize = ez5.fitRectangle(asset.value.versions.small.width, asset.value.versions.small.height, 30, 30)
			gps_location = asset.value.technical_metadata.gps_location
			if gps_location and gps_location.latitude and gps_location.longitude
				do(asset) =>
					markersOptions.push(
						position:
							lat: gps_location.latitude,
							lng: gps_location.longitude
						icon: L.icon(iconUrl: asset.value.versions.small.url, iconSize: iconSize)
						cui_onClick: =>
							CUI.Events.trigger
								node: @_detailSidebar.container
								type: "asset-browser-show-asset"
								info:
									value: asset.value
				)

		markersOptions

ez5.session_ready =>
	DetailSidebar.plugins.registerPlugin(MapDetailPlugin)