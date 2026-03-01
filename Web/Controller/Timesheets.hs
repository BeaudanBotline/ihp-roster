module Web.Controller.Timesheets where

import Web.Controller.Prelude
import Web.View.Timesheets.Index

instance Controller TimesheetsController where
    beforeAction = do
        ensureIsUser
        ensureProfileCompleted

    action TimesheetsAction = do
        render IndexView
