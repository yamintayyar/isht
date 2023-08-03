import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import "secret.dart";
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:nominatim_geocoding/nominatim_geocoding.dart';

void main() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'ISHT',
      home: Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late GoogleMapController mapController;

  final LatLng _center =
      const LatLng(40, -102); //centred around middle of USA, arbitrary

  List<Marker> markers = [];

  void _onMapCreated(GoogleMapController controller) async {
    mapController = controller;

    DatabaseReference ref = FirebaseDatabase.instance.ref();
    DatabaseEvent event = await ref.once();

    try {
      //in case of empty database, app wont crash

      // Map<dynamic, Map<dynamic, dynamic>>? vals =
      //     event.snapshot.value as Map<dynamic, Map>?;

      Map<dynamic,dynamic> map = event.snapshot.value as Map;
      List vals = map.values.toList();

      // print(vals['country']);

      if (vals != null) {
        for (var user in vals) {
          print(user.toString());

          // var temp = user as Map<dynamic, dynamic>;

          markers.add(Marker(
              markerId: MarkerId(user.hashCode.toString()),
              position: LatLng(user['lat'], user['lng'])));
        }
      }
    } catch (e) {
      print(e);
    }

    print(markers);

    setState(() {

    });
  }

  TextEditingController controller = TextEditingController();

  // FirebaseDatabase db = FirebaseDatabase.instance;
  // DatabaseReference ref = FirebaseDatabase.instance.ref();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
            child: SingleChildScrollView(
                child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 700,
              height: 900,
              child: GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition:
                    CameraPosition(target: _center, zoom: 3.0),
                markers: Set<Marker>.of(markers),
              ), //TODO: make scrollable list change to show country-specific complaints
            ),
            Container(
              width: 350,
              height: 600,
              // color: Colors.lightBlueAccent.withOpacity(0.5),
              child: Card(
                elevation: 4,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15.0)),
                child: ListView(
                  padding: const EdgeInsets.all(8),
                  //TODO:use database to make scrollable list of comments here
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(15.0),
          child: Container(
            width: 600,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.multiline,
              maxLines: null,
              autofocus: false,
              decoration: InputDecoration(
                labelText: "Speak your mind!",
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(20.0),
          child: MaterialButton(
            color: Colors.white70,
            height: 50,
            minWidth: 200,
            elevation: 4,
            onPressed: () async {
              final message = controller.text; //gets users message

              Position pos = await Geolocator.getCurrentPosition(
                  desiredAccuracy: LocationAccuracy
                      .lowest); //gives user location coordinates
              //TODO: add popup that tells user to refresh after enabling location services if they r disabled

              final response = await http.get(Uri.parse(
                  'https://us1.locationiq.com/v1/reverse?key=$GEOCODING_API_KEY&lat=${pos.latitude}&lon=${pos.longitude}&format=json'));
              var result = jsonDecode(response.body);
              String country = result['address']
                  ['country']; //gets country of user, using LocationIQ API

              DatabaseReference db_ref = FirebaseDatabase.instance.ref();
              DatabaseReference new_post_ref = db_ref.push();

              await new_post_ref.set({
                'country': country,
                'lng': pos.longitude,
                //edit slightly to avoid doxxing
                'lat': pos.latitude,
                //''
                'message': message
              });

              setState(() {});
            },
            child: Text("It Sucks Here, Too!"),
          ),
        ),
        const Padding(
          padding: const EdgeInsets.all(15.0),
          child: const Text(
              'Click on a country to view how it sucks, or leave a comment detailing why!'),
        )
      ],
    ))));
  }
}
