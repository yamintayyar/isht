import 'dart:collection';
import 'dart:convert';
import 'dart:io';
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
  HashMap<String, List<String>> dict = new HashMap();
  int lv_length = 0;

  void _onMapCreated(GoogleMapController controller) async {
    mapController = controller;

    DatabaseReference ref = FirebaseDatabase.instance.ref();
    DatabaseEvent event = await ref.once();

    try {
      //in case of empty database, app wont crash

      // Map<dynamic, Map<dynamic, dynamic>>? vals =
      //     event.snapshot.value as Map<dynamic, Map>?;

      Map<dynamic, dynamic> map = event.snapshot.value as Map;
      List vals = map.values.toList();

      // print(vals['country']);

      if (vals != null) {
        for (var user in vals) {
          print(user.toString());
          print(user['country']);

          markers.add(Marker(
              markerId: MarkerId(user.hashCode.toString()),
              position: LatLng(user['lat'], user['lng'])));

          String country = user['country'];

          if (dict[country] == null) {
            //if we have included users from a certain country in the map, then add current user to the country. else, add a new list with the user in it
            dict[country] = [user['message']];
          } else {
            // print(user['message'].runtimeType);
            dict[country]?.add(user['message']);
          }
        }
      }

      print('Success! Local data is: $dict'); //TESTING
    } catch (e) {
      print('Error! We have a problem: $e}');
    }

    lv_length = dict[display_country]!.length;

    setState(() {
      print('Loaded data');
    });
  }

  TextEditingController controller = TextEditingController();

  String display_country =
      'Canada'; //text to display selected country, TESTING: canada by default

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SingleChildScrollView(
      child: Center(
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
                  child: GoogleMap( //TODO: add functionality for marker onclick, view relevant country's complaints instead
                    onMapCreated: _onMapCreated,
                    initialCameraPosition:
                        CameraPosition(target: _center, zoom: 3.0),
                    markers: Set<Marker>.of(markers),
                  ),
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
                    child: Center(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              '$display_country',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ),
                          ListView.builder(
                            itemCount: lv_length,
                            itemBuilder: (BuildContext context, int index) {
                              return ListTile(
                                title: Text(dict[display_country]![index]),
                              );
                            },
                            shrinkWrap: true,
                            padding: const EdgeInsets.all(8),
                          ),
                        ],
                      ),
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
        ),
      ),
    ));
  }
}
