module Web.Controller.Admin where

import Web.Controller.Prelude
import Web.View.Admin.Index

instance Controller AdminController where
    beforeAction = do
        ensureIsUser
        ensureProfileCompleted
        ensureAdminRole

    action AdminAction = do
        render IndexView
