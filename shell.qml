//@ pragma Env QS_NO_RELOAD_POPUP=1

import "modules"
import "modules/drawers"
import "modules/background"
import "modules/areapicker"
import "modules/lock"
import "config"
import Quickshell
import QtQuick

ShellRoot {
    Loader {
      active: Config.background.enabled
      sourceComponent: Background {}
    }
    Drawers {}
    Loader {
      active: Config.areapicker.enabled
      sourceComponent: AreaPicker {}
    }
    Loader {
      active: Config.lock.enabled
      sourceComponent: Lock {}
    }
    Shortcuts {}
}
