import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(MaterialApp(
    home: FitApp(),
    debugShowCheckedModeBanner: false, // Remove debug banner
  ));
}

class FitApp extends StatefulWidget {
  @override
  _FitAppState createState() => _FitAppState();
}

class _FitAppState extends State<FitApp> {
  late GoogleSignIn _googleSignIn;
  late String _accessToken;
  late String _userName = '';
  late String _userPhotoUrl = '';
  bool _isSignedIn = false;
  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _googleSignIn = GoogleSignIn(
      scopes: ['https://www.googleapis.com/auth/fitness.activity.read'],
    );
  }

  Future<void> _authorizeGoogleFit() async {
    final googleSignInAccount = await _googleSignIn.signIn();
    final googleSignInAuthentication =
        await googleSignInAccount!.authentication;
    final googleSignInCurrentUser = _googleSignIn.currentUser;

    setState(() {
      _accessToken = googleSignInAuthentication.accessToken!;
      _userName = googleSignInCurrentUser?.displayName ?? '';
      _userPhotoUrl = googleSignInCurrentUser?.photoUrl ?? '';
      _isSignedIn = true;
    });
  }

  Future<void> _signOutGoogleFit() async {
    await _googleSignIn.signOut();
    setState(() {
      _accessToken = '';
      _userName = '';
      _userPhotoUrl = '';
      _isSignedIn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text('Google Fit Demo'),
        backgroundColor: Colors.blueGrey,
        actions: [
          if (_isSignedIn)
            GestureDetector(
              onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
              child: Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: CircleAvatar(
                  backgroundImage: NetworkImage(_userPhotoUrl),
                  radius: 16.0,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'images/athlete_background.jpg',
            fit: BoxFit.cover,
          ),
          Container(
            color: Colors.black.withOpacity(0.5),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_isSignedIn)
                  Column(
                    children: [
                      Text(
                        'Login to connect with Google Fit',
                        style: TextStyle(
                          fontSize: 20.0,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 16.0),
                      ElevatedButton(
                        onPressed: _authorizeGoogleFit,
                        style: ElevatedButton.styleFrom(
                          primary: Colors.blueGrey,
                          padding: EdgeInsets.symmetric(
                            vertical: 12.0,
                            horizontal: 24.0,
                          ),
                        ),
                        child: Text(
                          'Connect',
                          style: TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      Text(
                        'Hello $_userName !',
                        style: TextStyle(
                          fontSize: 20.0,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 16.0),
                      StepCountScreen(_userName, _accessToken),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blueGrey,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(_userPhotoUrl),
                    radius: 32.0,
                  ),
                  SizedBox(height: 16.0),
                  Text(
                    _userName,
                    style: TextStyle(
                      fontSize: 18.0,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.logout,
                color: Colors.blueGrey,
              ),
              title: Text(
                'Logout',
                style: TextStyle(
                  fontSize: 16.0,
                  color: Colors.blueGrey,
                ),
              ),
              onTap: _signOutGoogleFit,
            ),
          ],
        ),
      ),
    );
  }
}

class StepCountScreen extends StatefulWidget {
  final String userName;
  final String accessToken;

  StepCountScreen(this.userName, this.accessToken);

  @override
  _StepCountScreenState createState() => _StepCountScreenState();
}

class _StepCountScreenState extends State<StepCountScreen> {
  int _stepCount = 0;
  bool _isLoading = true;

  Future<void> _getStepCount() async {
    final response = await http.get(
      Uri.parse('https://www.googleapis.com/fitness/v1/users/me/dataSources'),
      headers: {'Authorization': 'Bearer ${widget.accessToken}'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final stepCountDataSources = data['dataSource'].where((dataSource) =>
          dataSource['dataStreamName'] ==
          'derived:com.google.step_count.delta:com.google.android.gms:estimated_steps');

      if (stepCountDataSources.isNotEmpty) {
        final dataSourceId = stepCountDataSources.first['dataStreamId'];
        final endTime = DateTime.now().millisecondsSinceEpoch;
        final startTime =
            DateTime.now().subtract(Duration(hours: 24)).millisecondsSinceEpoch;

        final uri = Uri.parse(
                'https://www.googleapis.com/fitness/v1/users/me/dataset:aggregate')
            .replace(
          queryParameters: {
            'aggregateBy': '[{"dataTypeName":"com.google.step_count.delta","dataSourceId":"$dataSourceId"}]',
            'bucketByTime': '1d',
            'startTimeMillis': '$startTime',
            'endTimeMillis': '$endTime',
          },
        );

        final stepCountResponse = await http.get(
          uri,
          headers: {'Authorization': 'Bearer ${widget.accessToken}'},
        );

        if (stepCountResponse.statusCode == 200) {
          final stepCountData = json.decode(stepCountResponse.body);
          final buckets = stepCountData['bucket'];
          if (buckets.isNotEmpty) {
            final dataset = buckets.first['dataset'].first;
            final stepCount = dataset['point'].first['value'].first['intVal'];
            setState(() {
              _stepCount = stepCount;
            });
          }
        }
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _getStepCount();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isLoading)
          CircularProgressIndicator()
        else
          Text(
            'Step Count: $_stepCount',
            style: TextStyle(fontSize: 18.0, color: Colors.white),
          ),
        SizedBox(height: 16.0),
        ElevatedButton(
          onPressed: _getStepCount,
          style: ElevatedButton.styleFrom(
            primary: Colors.blueGrey,
            padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
          ),
          child: Text(
            'Refresh',
            style: TextStyle(
              fontSize: 16.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
