{ packages =
  [ { id = "idrall"
    , repo = "https://github.com/alexhumphreys/idrall.git"
    , ipkgFile = "./idrall.ipkg"
    , depends = [] : List Text
    }
  , { id = "collie"
    , repo = "https://github.com/ohad/collie.git"
    , ipkgFile = "collie.ipkg"
    , depends = [] : List Text
    }
  , { id = "katla"
    , repo = "https://github.com/idris-community/katla.git"
    , ipkgFile = "katla.ipkg"
    , depends = ["idrall", "collie"] : List Text
    }
  ]
}
