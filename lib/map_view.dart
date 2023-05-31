import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:location/location.dart';
import 'package:mapbox_gl/mapbox_gl.dart';

class MapView extends StatefulWidget {
  const MapView({Key? key}) : super(key: key);

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  MapboxMapController? mapController;
  var marker;
  Map? modifiedResponse;
  late String distance;
  late String dropOffTime;
  Map? geometry;
  Duration? duration;
  final List<CameraPosition> kTripEndPoints = [];
  String accessToken =
      "pk.eyJ1IjoiZXZhbm92MSIsImEiOiJjbGhpczI5NnYwYXhnM2VtdThmeTJpOWo3In0.G9ZugLyobYU8uE7Er5cADw";

  onMapCreated(MapboxMapController controller) {
    try {
      mapController = controller;
      markerImage(icon: "assets/destination.png").then((value) {
        setState(() {
          marker = value;
        });
        LatLng latlong= LatLng(37.0902, 95.7129);
        addMarker(markerKey: "key", markerImage: marker, latlong: latlong)
            .then((value) {
          getCurrentLocation().then((current) {
            createPolyline(
                polylineSource: LatLng(current.latitude!, current.longitude!),
                polylineDestination:
                LatLng(latlong.latitude, latlong.longitude),
                navType: "driving");
          });
        });
      });

    } catch (e) {
      print(e);
    }
  }

  Future<Uint8List> markerImage({required String icon}) async {
    var byteData = await rootBundle.load(icon);
    return await byteData.buffer.asUint8List();
  }

  Future<void> addMarker({
    required String markerKey,
    required markerImage,
    required LatLng latlong,
  }) async {
    mapController!.clearSymbols();
    mapController!.addImage(markerKey, markerImage);
    await mapController!.addSymbol(
      SymbolOptions(
        iconSize: 0.13,
        iconImage: markerKey,
        geometry: latlong,
        iconAnchor: "bottom",
      ),
    );
  }

  Future<LocationData> getCurrentLocation() async {
    Location location = Location();
    bool serviceEnabled = false;
    PermissionStatus? permissionGranted;
    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {}
    }
    permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        // SystemNavigator.pop();
      }
    }
    return await location.getLocation();
  }

  Future<void> moveCameraToLocation({
    required MapboxMapController mapController,
    required LatLng latLng,
    required double zoom,
    required double tilt,
    required double bearing,
  }) async {
    mapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          bearing: bearing,
          target: LatLng(latLng.latitude, latLng.longitude),
          zoom: zoom,
          tilt: tilt,
        ),
      ),
    );
  }

  Future<void> createPolyline({
    required LatLng polylineSource,
    required LatLng polylineDestination,
    required String navType,
  }) async {
    modifiedResponse = await getDirectionsAPIResponse(
        polylineSource, polylineDestination, navType);

    // distance = (modifiedResponse!['distance'] / 1000).toStringAsFixed(1);
    geometry = modifiedResponse!['geometry'];

    duration = Duration(
      minutes: (modifiedResponse!['duration'] / 60).round(),
      seconds: 0,
      // seconds: (modifiedResponse!['duration'] % 60).round(),
      milliseconds: 0,
      microseconds: 0,
    );

    print("geometry");
    print(geometry);

    kTripEndPoints.add(CameraPosition(target: polylineSource));
    kTripEndPoints.add(CameraPosition(target: polylineDestination));

    addSourceAndLineLayer(geometry);

  }

  addSourceAndLineLayer(geo) async {
    // Create a polyLine between source and destination

    var _fills = {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "id": 0,
          "properties": <String, dynamic>{},
          "geometry": geo,
        },
      ],
    };


      await mapController!.addGeoJsonSource("fills", _fills);

      await mapController!.addLineLayer(
        "fills",
        "lines",
        LineLayerProperties(
          lineColor: Colors.indigo.toHexStringRGB(),
          //lineColor: Colors.blue.shade700.toHexStringRGB(),
          lineCap: "round",
          lineJoin: "round",
          lineWidth: 3,
        ),
      );
  }

  Future<Map> getDirectionsAPIResponse(
      LatLng sourceLatLng, LatLng destinationLatLng, String navType) async {
    final response = await getCyclingRouteUsingMapbox(
        sourceLatLng, destinationLatLng, navType);
    Map geometry = response['routes'][0]['geometry'];
    num duration = response['routes'][0]['duration'];
    num distance = response['routes'][0]['distance'];

    Map modifiedResponse = {
      "geometry": geometry,
      "duration": duration,
      "distance": distance,
    };
    return modifiedResponse;
  }

  Future getCyclingRouteUsingMapbox(
      LatLng source, LatLng destination, String navType) async {
    Dio dio = Dio();
    String baseUrl = 'https://api.mapbox.com/directions/v5/mapbox';
    String url =
        '${baseUrl}/${navType}/${source.longitude},${source.latitude};${destination.longitude},${destination.latitude}?alternatives=true&continue_straight=true&geometries=geojson&language=en&overview=full&steps=true&access_token=$accessToken';
    try {
      dio.options.contentType = Headers.jsonContentType;
      final responseData = await dio.get(url);
      return responseData.data;
    } catch (e) {
      // final errorMessage = DioExceptions.fromDioError(e as DioError).toString();
      // debugPrint(errorMessage);
      print("e");
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Mapbox"),
      ),
      body: MapboxMap(
        styleString: MapboxStyles.MAPBOX_STREETS,
        accessToken: accessToken,
        onMapCreated: onMapCreated,
        initialCameraPosition: CameraPosition(
          target: LatLng(28.4212, 70.2989),
          // target: getCenterCoordinatesForPolyline(geometry!),
          zoom: 0,
        ),
        myLocationEnabled: true,
        myLocationTrackingMode: MyLocationTrackingMode.TrackingGPS,

      ),
      floatingActionButton: FloatingActionButton(
        child: Text("Zoom"),
        onPressed: () {
          getCurrentLocation().then((value) {
            moveCameraToLocation(
              mapController: mapController!,
              latLng: LatLng(value.latitude!, value.longitude!),
              // latLng: LatLng(Token.latitude, Token.longitude),
              bearing: value.heading!,
              zoom: 11,
              tilt: 0,
            );
          });
        },
      ),
    );
  }
}
