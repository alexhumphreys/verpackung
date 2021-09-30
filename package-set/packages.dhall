{ packages =
  [ { id = "idrall"
    , repo = "https://github.com/alexhumphreys/idrall.git"
    , ipkgFile = "./idrall.ipkg"
    , depends = [] : List Text
    }
  , { id = "collie"
    , repo = "https://github.com/ohad/collie.git"
    , ipkgFile = "./collie.ipkg"
    , depends = [] : List Text
    }
  , { id = "elab-util"
    , repo = "https://github.com/stefan-hoeck/idris2-elab-util.git"
    , ipkgFile = "./elab-util.ipkg"
    , depends = [] : List Text
    }
  , { id = "comonad"
    , repo = "https://github.com/stefan-hoeck/idris2-comonad.git"
    , ipkgFile = "./comonad.ipkg"
    , depends = [] : List Text
    }
  , { id = "frex"
    , repo = "https://github.com/frex-project/idris-frex.git"
    , ipkgFile = "./frex.ipkg"
    , depends = [] : List Text
    }
  , { id = "sop"
    , repo = "https://github.com/stefan-hoeck/idris2-sop.git"
    , ipkgFile = "./sop.ipkg"
    , depends = ["elab-util"] : List Text
    }
  , { id = "katla"
    , repo = "https://github.com/idris-community/katla.git"
    , ipkgFile = "./katla.ipkg"
    , depends = ["idrall", "collie"] : List Text
    }
  , { id = "pretty-show"
    , repo = "https://github.com/stefan-hoeck/idris2-pretty-show.git"
    , ipkgFile = "./pretty-show.ipkg"
    , depends = ["elab-util", "sop"] : List Text
    }
  ]
}
