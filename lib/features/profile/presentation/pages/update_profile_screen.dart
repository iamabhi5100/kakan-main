import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kakan/core/network/models/verify_otp_response.dart';
import 'package:kakan/core/network/models/user_details.dart';
import 'package:kakan/core/utils/session_manager.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_detail/profiledetails_bloc.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_detail/profiledetails_event.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_detail/profiledetails_state.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_image/profileimage_bloc.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_image/profileimage_event.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_image/profileimage_state.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_submit/profile_submit_bloc.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_submit/profile_submit_event.dart';
import 'package:kakan/features/profile/presentation/bloc/profile_submit/profile_submit_state.dart';
import 'package:kakan/injection_container.dart' as di;
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:io';
import 'package:go_router/go_router.dart';

class UpdateProfileScreen extends StatefulWidget {
  const UpdateProfileScreen({super.key});

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dateOfBirthController = TextEditingController();

  String _selectedGender = "Male";
  String _selectedOccupation = "Student";
  final List<String> _genderOptions = ["Male", "Female", "Other"];
  final List<String> _occupationOptions = ["Student", "Professional", "Other"];
  String? _usernameError;
  File? _selectedImage;
  String? _profileImageUrl;
  bool _hasFetchedDetails = false;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      print('UpdateProfileScreen: initState called');
    }
    try {
      if (di.sl.isRegistered<SessionManager>()) {
        if (kDebugMode) {
          print('UpdateProfileScreen: SessionManager is registered');
        }
      } else {
        if (kDebugMode) {
          print('UpdateProfileScreen: SessionManager is NOT registered');
        }
      }
      if (di.sl.isRegistered<ProfileimageBloc>()) {
        if (kDebugMode) {
          print('UpdateProfileScreen: ProfileimageBloc is registered');
        }
      } else {
        if (kDebugMode) {
          print('UpdateProfileScreen: ProfileimageBloc is NOT registered');
        }
      }
      if (di.sl.isRegistered<ProfiledetailsBloc>()) {
        if (kDebugMode) {
          print('UpdateProfileScreen: ProfiledetailsBloc is registered');
        }
      } else {
        if (kDebugMode) {
          print('UpdateProfileScreen: ProfiledetailsBloc is NOT registered');
        }
      }
      if (di.sl.isRegistered<ProfileSubmitBloc>()) {
        if (kDebugMode) {
          print('UpdateProfileScreen: ProfileSubmitBloc is registered');
        }
      } else {
        if (kDebugMode) {
          print('UpdateProfileScreen: ProfileSubmitBloc is NOT registered');
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('UpdateProfileScreen: Error in initState: $e');
        print('Stack trace: $stackTrace');
      }
    }
  }

  Future<void> _fetchUserDetails(BuildContext context) async {
    if (kDebugMode) {
      print('UpdateProfileScreen: _fetchUserDetails called');
    }
    try {
      final sessionManager = di.sl<SessionManager>();
      final userId = await sessionManager.getProfileId();
      if (userId == null) {
        if (mounted) {
          if (kDebugMode) {
            print('UpdateProfileScreen: User ID is null');
          }
          Fluttertoast.showToast(
            msg: 'User ID not found. Please log in again.',
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.TOP,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0,
          );
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }
      if (kDebugMode) {
        print('UpdateProfileScreen: Fetching user details for userId: $userId');
      }
      context.read<ProfiledetailsBloc>().add(GetProfiledetailsEvent(userId: userId));
    } catch (e, stackTrace) {
      if (mounted) {
        if (kDebugMode) {
          print('UpdateProfileScreen: Error in _fetchUserDetails: $e');
          print('Stack trace: $stackTrace');
        }
        Fluttertoast.showToast(
          msg: 'Error fetching user details: $e',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.TOP,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    }
  }

  @override
  void dispose() {
    if (kDebugMode) {
      print('UpdateProfileScreen: dispose called');
    }
    _fullNameController.dispose();
    _usernameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _dateOfBirthController.dispose();
    super.dispose();
  }

  void _validateUsername(String value) {
    setState(() {
      _usernameError = value.isEmpty
          ? "Username cannot be empty"
          : value.length < 3
              ? "Username must be at least 3 characters"
              : null;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1997, 1, 15),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dateOfBirthController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  String _formatDateForApi(String date) {
    final parts = date.split('/');
    if (parts.length == 3) {
      return "${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}";
    }
    return date;
  }

  String _formatDateForDisplay(String? date) {
    if (date == null || date.isEmpty) return '';
    final parts = date.split('-');
    if (parts.length == 3) {
      return "${parts[2]}/${parts[1]}/${parts[0]}";
    }
    return date;
  }

  Future<void> _pickImage(BuildContext context) async {
    if (kDebugMode) {
      print('UpdateProfileScreen: _pickImage called');
    }
    try {
      final profileImageBloc = context.read<ProfileimageBloc>();
      if (profileImageBloc.state is ProfileimageLoading) {
        if (kDebugMode) {
          print('UpdateProfileScreen: ProfileimageBloc is loading, skipping image pick');
        }
        return;
      }
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _profileImageUrl = null;
        });
        final sessionManager = di.sl<SessionManager>();
        final userId = await sessionManager.getProfileId();
        if (userId == null) {
          if (mounted) {
            if (kDebugMode) {
              print('UpdateProfileScreen: User ID is null in _pickImage');
            }
            Fluttertoast.showToast(
              msg: 'User ID not found. Please complete your profile first.',
              toastLength: Toast.LENGTH_LONG,
              gravity: ToastGravity.TOP,
              backgroundColor: Colors.red,
              textColor: Colors.white,
              fontSize: 16.0,
            );
            Navigator.pushReplacementNamed(context, '/onboarding-form');
          }
          return;
        }
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          if (kDebugMode) {
            print('UpdateProfileScreen: Uploading image for userId: $userId');
          }
          context.read<ProfileimageBloc>().add(
                UploadProfileimageEvent(userId: userId, imagePath: pickedFile.path),
              );
        }
      }
    } catch (e, stackTrace) {
      if (mounted) {
        if (kDebugMode) {
          print('UpdateProfileScreen: Error in _pickImage: $e');
          print('Stack trace: $stackTrace');
        }
        Fluttertoast.showToast(
          msg: 'Error picking image: $e',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.TOP,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    }
  }

  bool _isFormValid() {
    final emailPattern = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return _usernameError == null &&
        _fullNameController.text.isNotEmpty &&
        _dateOfBirthController.text.isNotEmpty &&
        _selectedOccupation.isNotEmpty &&
        (_emailController.text.isEmpty || emailPattern.hasMatch(_emailController.text)) &&
        _dateOfBirthController.text.contains(RegExp(r'^\d{1,2}/\d{1,2}/\d{4}$'));
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      print('UpdateProfileScreen: build called');
    }
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: di.sl<ProfiledetailsBloc>()),
        BlocProvider.value(value: di.sl<ProfileimageBloc>()),
        BlocProvider.value(value: di.sl<ProfileSubmitBloc>()),
      ],
      child: Builder(
        builder: (blocContext) {
          if (kDebugMode) {
            print('UpdateProfileScreen: MultiBlocProvider Builder called');
          }
          if (!_hasFetchedDetails) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_hasFetchedDetails) {
                setState(() {
                  _hasFetchedDetails = true;
                });
                _fetchUserDetails(blocContext);
              }
            });
          }
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (kDebugMode) {
                    print('UpdateProfileScreen: Back button pressed');
                  }
                  // NEW: Check if can pop; if not, navigate to /home
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    context.go('/home');
                  }
                },
              ),
              title: const Text('Edit Profile'),
            ),
            body: BlocListener<ProfiledetailsBloc, ProfiledetailsState>(
              listener: (context, detailsState) {
                if (kDebugMode) {
                  print('UpdateProfileScreen: ProfiledetailsBloc state: $detailsState');
                }
                try {
                  if (detailsState is ProfiledetailsLoaded) {
                    if (kDebugMode) {
                      print('UpdateProfileScreen: ProfiledetailsLoaded with data: '
                          'name=${detailsState.profileDetails.name}, '
                          'username=${detailsState.profileDetails.username}, '
                          'phone=${detailsState.profileDetails.phone}, '
                          'email=${detailsState.profileDetails.email}, '
                          'dateOfBirth=${detailsState.profileDetails.dateOfBirth}');
                    }
                    bool needsUpdate = false;
                    if (_fullNameController.text != (detailsState.profileDetails.name ?? 'N/A')) {
                      _fullNameController.text = detailsState.profileDetails.name ?? 'N/A';
                      needsUpdate = true;
                    }
                    if (_usernameController.text != (detailsState.profileDetails.username ?? 'N/A')) {
                      _usernameController.text = detailsState.profileDetails.username ?? 'N/A';
                      needsUpdate = true;
                    }
                    if (_mobileController.text != (detailsState.profileDetails.phone ?? 'N/A')) {
                      _mobileController.text = detailsState.profileDetails.phone ?? 'N/A';
                      needsUpdate = true;
                    }
                    if (_emailController.text != (detailsState.profileDetails.email ?? 'N/A')) {
                      _emailController.text = detailsState.profileDetails.email ?? 'N/A';
                      needsUpdate = true;
                    }
                    if (_dateOfBirthController.text != _formatDateForDisplay(detailsState.profileDetails.dateOfBirth)) {
                      _dateOfBirthController.text = _formatDateForDisplay(detailsState.profileDetails.dateOfBirth);
                      needsUpdate = true;
                    }
                    String newGender = detailsState.profileDetails.gender?.isNotEmpty == true &&
                            _genderOptions.contains(detailsState.profileDetails.gender)
                        ? detailsState.profileDetails.gender!
                        : _genderOptions.first;
                    String newOccupation = detailsState.profileDetails.occupation?.isNotEmpty == true &&
                            _occupationOptions.contains(detailsState.profileDetails.occupation)
                        ? detailsState.profileDetails.occupation!
                        : _occupationOptions.first;
                    if (_selectedGender != newGender || _selectedOccupation != newOccupation) {
                      _selectedGender = newGender;
                      _selectedOccupation = newOccupation;
                      needsUpdate = true;
                    }
                    if (_profileImageUrl != detailsState.profileDetails.profileImage) {
                      _profileImageUrl = detailsState.profileDetails.profileImage;
                      needsUpdate = true;
                    }
                    if (needsUpdate && mounted) {
                      setState(() {});
                    }
                    if (kDebugMode) {
                      print('UpdateProfileScreen: Updated controllers: '
                          'fullName=${_fullNameController.text}, '
                          'username=${_usernameController.text}, '
                          'mobile=${_mobileController.text}, '
                          'email=${_emailController.text}, '
                          'dateOfBirth=${_dateOfBirthController.text}');
                    }
                  } else if (detailsState is ProfiledetailsError) {
                    if (kDebugMode) {
                      print('UpdateProfileScreen: ProfiledetailsError: ${detailsState.message}');
                    }
                    if (mounted) {
                      Fluttertoast.showToast(
                        msg: 'Error: ${detailsState.message}',
                        toastLength: Toast.LENGTH_LONG,
                        gravity: ToastGravity.TOP,
                        backgroundColor: Colors.red,
                        textColor: Colors.white,
                        fontSize: 16.0,
                      );
                    }
                  }
                } catch (e, stackTrace) {
                  if (kDebugMode) {
                    print('UpdateProfileScreen: Error in ProfiledetailsBloc listener: $e');
                    print('Stack trace: $stackTrace');
                  }
                  if (mounted) {
                    Fluttertoast.showToast(
                      msg: 'Unexpected error in profile listener: $e',
                      toastLength: Toast.LENGTH_LONG,
                      gravity: ToastGravity.TOP,
                      backgroundColor: Colors.red,
                      textColor: Colors.white,
                      fontSize: 16.0,
                    );
                  }
                }
              },
              child: BlocListener<ProfileimageBloc, ProfileimageState>(
                listener: (context, imageState) {
                  if (kDebugMode) {
                    print('UpdateProfileScreen: ProfileimageBloc state: $imageState');
                  }
                  try {
                    if (imageState is ProfileimageUploaded) {
                      if (kDebugMode) {
                        print('UpdateProfileScreen: ProfileimageUploaded: ${imageState.message}');
                      }
                      if (mounted) {
                        Fluttertoast.showToast(
                          msg: imageState.message,
                          toastLength: Toast.LENGTH_SHORT,
                          gravity: ToastGravity.TOP,
                          backgroundColor: Colors.green,
                          textColor: Colors.white,
                          fontSize: 16.0,
                        );
                        setState(() {
                          _selectedImage = null;
                          _profileImageUrl = null;
                        });
                        _fetchUserDetails(blocContext);
                      }
                    } else if (imageState is ProfileimageError) {
                      if (kDebugMode) {
                        print('UpdateProfileScreen: ProfileimageError: ${imageState.message}');
                      }
                      if (mounted) {
                        Fluttertoast.showToast(
                          msg: imageState.message,
                          toastLength: Toast.LENGTH_LONG,
                          gravity: ToastGravity.TOP,
                          backgroundColor: Colors.red,
                          textColor: Colors.white,
                          fontSize: 16.0,
                        );
                        if (imageState.message.contains('No UserProfile matches')) {
                          Navigator.pushReplacementNamed(context, '/onboarding-form');
                        }
                      }
                    }
                  } catch (e, stackTrace) {
                    if (kDebugMode) {
                      print('UpdateProfileScreen: Error in ProfileimageBloc listener: $e');
                      print('Stack trace: $stackTrace');
                    }
                    if (mounted) {
                      Fluttertoast.showToast(
                        msg: 'Unexpected error in image listener: $e',
                        toastLength: Toast.LENGTH_LONG,
                        gravity: ToastGravity.TOP,
                        backgroundColor: Colors.red,
                        textColor: Colors.white,
                        fontSize: 16.0,
                      );
                    }
                  }
                },
                child: BlocListener<ProfileSubmitBloc, ProfileSubmitState>(
                  listener: (context, submitState) async {
                    if (kDebugMode) {
                      print('UpdateProfileScreen: ProfileSubmitBloc state: $submitState');
                    }
                    try {
                      if (submitState is ProfileSubmitSuccess) {
                        if (kDebugMode) {
                          print('UpdateProfileScreen: ProfileSubmitSuccess');
                        }
                        if (mounted) {
                          // Update VerifyOtpResponse in SessionManager
                          final sessionManager = di.sl<SessionManager>();
                          final currentResponse = await sessionManager.getVerifyOtpResponse();
                          if (currentResponse != null) {
                            final updatedUserDetails = UserDetails(
                              id: submitState.profileDetails.id,
                              internalId: currentResponse.userDetails?.internalId ?? '',
                              isFollowed: currentResponse.userDetails?.isFollowed ?? false,
                              followersCount: submitState.profileDetails.followersCount,
                              followingCount: submitState.profileDetails.followingCount,
                              showUpdateProfileCard: false,
                              created: currentResponse.userDetails?.created ?? '',
                              modified: currentResponse.userDetails?.modified ?? '',
                              internalCode: currentResponse.userDetails?.internalCode ?? '',
                              prefix: currentResponse.userDetails?.prefix ?? '',
                              sequenceNumber: currentResponse.userDetails?.sequenceNumber ?? 0,
                              userStatus: currentResponse.userDetails?.userStatus ?? '',
                              userType: currentResponse.userDetails?.userType ?? '',
                              username: submitState.profileDetails.username,
                              phone: submitState.profileDetails.phone,
                              email: submitState.profileDetails.email,
                              title: submitState.profileDetails.title,
                              name: submitState.profileDetails.name,
                              dateOfBirth: submitState.profileDetails.dateOfBirth,
                              gender: submitState.profileDetails.gender,
                              profileImage: submitState.profileDetails.profileImage,
                              occupation: submitState.profileDetails.occupation,
                              user: currentResponse.userDetails?.user ?? '',
                            );
                            final updatedResponse = VerifyOtpResponse(
                              accessToken: currentResponse.accessToken,
                              refreshToken: currentResponse.refreshToken,
                              isExisted: currentResponse.isExisted,
                              userDetails: updatedUserDetails,
                            );
                            await sessionManager.saveVerifyOtpResponse(updatedResponse);
                            if (kDebugMode) {
                              print('UpdateProfileScreen: Updated VerifyOtpResponse with showUpdateProfileCard: false');
                            }
                          }
                          Fluttertoast.showToast(
                            msg: 'Profile updated successfully!',
                            toastLength: Toast.LENGTH_SHORT,
                            gravity: ToastGravity.TOP,
                            backgroundColor: Colors.green,
                            textColor: Colors.white,
                            fontSize: 16.0,
                          );
                          if (kDebugMode) {
                            final accessToken = await sessionManager.getAccessToken();
                            print('UpdateProfileScreen: Access token before navigation: $accessToken');
                            print('UpdateProfileScreen: Attempting to navigate to /home');
                          }
                          try {
                            await _fetchUserDetails(context);
                            // Try GoRouter navigation
                            context.go('/home');
                            if (kDebugMode) {
                              print('UpdateProfileScreen: GoRouter navigation to /home executed');
                            }
                          } catch (e, stackTrace) {
                            if (kDebugMode) {
                              print('UpdateProfileScreen: GoRouter navigation error: $e');
                              print('Stack trace: $stackTrace');
                            }
                            Fluttertoast.showToast(
                              msg: 'GoRouter navigation failed: $e. Falling back to Navigator.',
                              toastLength: Toast.LENGTH_LONG,
                              gravity: ToastGravity.TOP,
                              backgroundColor: Colors.red,
                              textColor: Colors.white,
                              fontSize: 16.0,
                            );
                            // Fallback to Navigator
                            if (mounted) {
                              Navigator.pushReplacementNamed(context, '/home');
                              if (kDebugMode) {
                                print('UpdateProfileScreen: Navigator navigation to /home executed');
                              }
                            }
                          }
                        }
                      } else if (submitState is ProfileSubmitError) {
                        if (kDebugMode) {
                          print('UpdateProfileScreen: ProfileSubmitError: ${submitState.message}');
                        }
                        if (mounted) {
                          Fluttertoast.showToast(
                            msg: submitState.message,
                            toastLength: Toast.LENGTH_LONG,
                            gravity: ToastGravity.TOP,
                            backgroundColor: Colors.red,
                            textColor: Colors.white,
                            fontSize: 16.0,
                          );
                        }
                      }
                    } catch (e, stackTrace) {
                      if (kDebugMode) {
                        print('UpdateProfileScreen: Error in ProfileSubmitBloc listener: $e');
                        print('Stack trace: $stackTrace');
                      }
                      if (mounted) {
                        Fluttertoast.showToast(
                          msg: 'Unexpected error in profile submit listener: $e',
                          toastLength: Toast.LENGTH_LONG,
                          gravity: ToastGravity.TOP,
                          backgroundColor: Colors.red,
                          textColor: Colors.white,
                          fontSize: 16.0,
                        );
                      }
                    }
                  },
                  child: BlocBuilder<ProfiledetailsBloc, ProfiledetailsState>(
                    builder: (context, detailsState) {
                      if (kDebugMode) {
                        print('UpdateProfileScreen: BlocBuilder state: $detailsState');
                      }
                      if (detailsState is ProfiledetailsLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (detailsState is ProfiledetailsError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Failed to load profile: ${detailsState.message}'),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _hasFetchedDetails = false;
                                  });
                                  _fetchUserDetails(blocContext);
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        );
                      }
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Builder(
                                builder: (imageContext) {
                                  return GestureDetector(
                                    onTap: () => _pickImage(imageContext),
                                    child: Stack(
                                      children: [
                                        CircleAvatar(
                                          radius: 40,
                                          backgroundImage: _selectedImage != null
                                              ? FileImage(_selectedImage!)
                                              : _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                                                  ? NetworkImage(_profileImageUrl!)
                                                  : const AssetImage('assets/images/avataruser.png') as ImageProvider,
                                          backgroundColor: Colors.grey,
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.blue[800],
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.camera_alt,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text("Full Name*", style: TextStyle(fontSize: 16)),
                            TextField(
                              key: const ValueKey('full_name'),
                              controller: _fullNameController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'Enter full name',
                              ),
                            ),
                            if (kDebugMode) Text('Debug: ${_fullNameController.text}'),
                            const SizedBox(height: 16),
                            const Text("Username", style: TextStyle(fontSize: 16)),
                            TextField(
                              key: const ValueKey('username'),
                              controller: _usernameController,
                              enabled: false,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'Enter username',
                              ),
                            ),
                            if (kDebugMode) Text('Debug: ${_usernameController.text}'),
                            const SizedBox(height: 16),
                            const Text("Mobile", style: TextStyle(fontSize: 16)),
                            TextField(
                              key: const ValueKey('mobile'),
                              controller: _mobileController,
                              keyboardType: TextInputType.phone,
                              enabled: false,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'Mobile number',
                              ),
                            ),
                            if (kDebugMode) Text('Debug: ${_mobileController.text}'),
                            const SizedBox(height: 16),
                            const Text("Email", style: TextStyle(fontSize: 16)),
                            TextField(
                              key: const ValueKey('email'),
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              enabled: false,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'Email',
                              ),
                            ),
                            if (kDebugMode) Text('Debug: ${_emailController.text}'),
                            const SizedBox(height: 16),
                            const Text("Gender", style: TextStyle(fontSize: 16)),
                            DropdownButtonFormField<String>(
                              key: const ValueKey('gender'),
                              value: _selectedGender,
                              items: _genderOptions.map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: (newValue) {
                                setState(() {
                                  _selectedGender = newValue!;
                                });
                              },
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text("Date of Birth*", style: TextStyle(fontSize: 16)),
                            TextField(
                              key: const ValueKey('date_of_birth'),
                              controller: _dateOfBirthController,
                              readOnly: true,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.arrow_drop_down),
                                hintText: 'Select date of birth',
                              ),
                              onTap: () => _selectDate(context),
                            ),
                            if (kDebugMode) Text('Debug: ${_dateOfBirthController.text}'),
                            const SizedBox(height: 16),
                            const Text("What best describes you*", style: TextStyle(fontSize: 16)),
                            DropdownButtonFormField<String>(
                              key: const ValueKey('occupation'),
                              value: _selectedOccupation,
                              items: _occupationOptions.map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: (newValue) {
                                setState(() {
                                  _selectedOccupation = newValue!;
                                });
                              },
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isFormValid()
                                    ? () async {
                                        if (kDebugMode) {
                                          print('UpdateProfileScreen: Save Changes button pressed');
                                        }
                                        try {
                                          final sessionManager = di.sl<SessionManager>();
                                          final userId = await sessionManager.getProfileId();
                                          if (userId == null) {
                                            if (mounted) {
                                              if (kDebugMode) {
                                                print('UpdateProfileScreen: User ID is null in Save Changes');
                                              }
                                              Fluttertoast.showToast(
                                                msg: 'User ID not found. Please log in again.',
                                                toastLength: Toast.LENGTH_LONG,
                                                gravity: ToastGravity.TOP,
                                                backgroundColor: Colors.red,
                                                textColor: Colors.white,
                                                fontSize: 16.0,
                                              );
                                              Navigator.pushReplacementNamed(context, '/login');
                                            }
                                            return;
                                          }
                                          final data = {
                                            'username': _usernameController.text,
                                            'name': _fullNameController.text,
                                            'email': _emailController.text,
                                            'date_of_birth': _formatDateForApi(_dateOfBirthController.text),
                                            'gender': _selectedGender,
                                            'occupation': _selectedOccupation,
                                          };
                                          if (kDebugMode) {
                                            print('UpdateProfileScreen: Submitting profile update: $data');
                                          }
                                          context.read<ProfileSubmitBloc>().add(
                                                SubmitProfileEvent(userId: userId, data: data),
                                              );
                                        } catch (e, stackTrace) {
                                          if (mounted) {
                                            if (kDebugMode) {
                                              print('UpdateProfileScreen: Error in Save Changes: $e');
                                              print('Stack trace: $stackTrace');
                                            }
                                            Fluttertoast.showToast(
                                              msg: 'Error saving changes: $e',
                                              toastLength: Toast.LENGTH_LONG,
                                              gravity: ToastGravity.TOP,
                                              backgroundColor: Colors.red,
                                              textColor: Colors.white,
                                              fontSize: 16.0,
                                            );
                                          }
                                        }
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                child: Text(
                                  "SAVE CHANGES",
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}