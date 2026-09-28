
import 'package:shoplite/features/auth/data/models/login_response_model.dart';

abstract class AuthRemoteDatasource {

Future<LoginResponseModel> login(String username, String password);

}