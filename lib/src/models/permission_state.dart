/*
 * Copyright (c) 2020. Julian Steenbakker.
 * All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

enum PermissionState {
  /// The user granted access to the requested feature.
  granted,

  /// The user denied access to the requested feature, permission needs to be asked first.
  denied,

  /// Permission to the requested feature is permanently denied,
  /// the permission dialog will not be shown when requesting this permission.
  /// The user may still change the permission status in the settings.
  permanentlyDenied,

  /// The status is unknown
  unknown,

  /// The OS denied access to the requested feature.
  /// The user cannot change this app's status, possibly due to active restrictions such as parental controls being in place.
  ///
  /// Only supported on iOS.
  restricted,

  /// User has authorized this application for limited access.
  /// Only supported on iOS (iOS14+).
  limited,
}
