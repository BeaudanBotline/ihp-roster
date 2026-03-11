module Application.Helper.LiveUpdate
    ( LiveFragmentKey (..)
    , LiveFragmentRef (..)
    , LiveUpdateCommand (..)
    , LiveUpdateMessage (..)
    , LiveUpdateScope (..)
    , broadcastLiveInvalidation
    , registerLiveSubscription
    , unregisterLiveSubscription
    ) where

import qualified Control.Exception.Safe as Exception
import qualified Data.Aeson as Aeson
import qualified Data.Aeson.Types as Aeson
import Data.IORef
import qualified Data.Text as Text
import qualified Data.UUID as UUID
import IHP.Prelude
import qualified Network.WebSockets as WebSocket
import System.IO.Unsafe (unsafePerformIO)

data LiveUpdateScope
    = RosterWeekScope
        { venueId    :: !UUID.UUID
        , weekOffset :: !Int
        }
    deriving (Eq, Ord, Show)

data LiveFragmentKey
    = RosterContentFragment
    | RosterStaffPanelFragment
    | RosterRowFragment
        { rosterDayId :: !UUID.UUID
        , rowIndex    :: !Int
        }
    deriving (Eq, Ord, Show)

data LiveFragmentRef = LiveFragmentRef
    { fragmentKey    :: !LiveFragmentKey
    , targetId       :: !Text
    , url            :: !Text
    , deferUntilBlur :: !Bool
    }
    deriving (Eq, Show)

data LiveUpdateCommand
    = SubscribeLiveUpdates
        { scope    :: !LiveUpdateScope
        , clientId :: !Text
        }
    | UnsubscribeLiveUpdates
    deriving (Eq, Show)

data LiveUpdateMessage
    = LiveUpdatesSubscribed
        { scope :: !LiveUpdateScope
        }
    | LiveUpdatesInvalidated
        { scope          :: !LiveUpdateScope
        , fragments      :: ![LiveFragmentRef]
        , sourceClientId :: !(Maybe Text)
        }
    | LiveUpdatesError
        { message :: !Text
        }
    deriving (Eq, Show)

instance Aeson.ToJSON LiveUpdateScope where
    toJSON RosterWeekScope { venueId, weekOffset } =
        Aeson.object
            [ "kind" Aeson..= ("roster_week" :: Text)
            , "venueId" Aeson..= UUID.toText venueId
            , "weekOffset" Aeson..= weekOffset
            ]

instance Aeson.FromJSON LiveUpdateScope where
    parseJSON = Aeson.withObject "LiveUpdateScope" \object -> do
        kind <- object Aeson..: "kind"
        case (kind :: Text) of
            "roster_week" ->
                RosterWeekScope
                    <$> (parseUuid =<< object Aeson..: "venueId")
                    <*> object Aeson..: "weekOffset"
            _ -> fail ("Unknown live update scope kind: " <> cs kind)

instance Aeson.ToJSON LiveFragmentKey where
    toJSON RosterContentFragment =
        Aeson.object ["kind" Aeson..= ("roster_content" :: Text)]
    toJSON RosterStaffPanelFragment =
        Aeson.object ["kind" Aeson..= ("roster_staff_panel" :: Text)]
    toJSON RosterRowFragment { rosterDayId, rowIndex } =
        Aeson.object
            [ "kind" Aeson..= ("roster_row" :: Text)
            , "rosterDayId" Aeson..= UUID.toText rosterDayId
            , "rowIndex" Aeson..= rowIndex
            ]

instance Aeson.FromJSON LiveFragmentKey where
    parseJSON = Aeson.withObject "LiveFragmentKey" \object -> do
        kind <- object Aeson..: "kind"
        case (kind :: Text) of
            "roster_content" -> pure RosterContentFragment
            "roster_staff_panel" -> pure RosterStaffPanelFragment
            "roster_row" ->
                RosterRowFragment
                    <$> (parseUuid =<< object Aeson..: "rosterDayId")
                    <*> object Aeson..: "rowIndex"
            _ -> fail ("Unknown live fragment kind: " <> cs kind)

instance Aeson.ToJSON LiveFragmentRef where
    toJSON LiveFragmentRef { fragmentKey, targetId, url, deferUntilBlur } =
        Aeson.object
            [ "fragmentKey" Aeson..= fragmentKey
            , "targetId" Aeson..= targetId
            , "url" Aeson..= url
            , "deferUntilBlur" Aeson..= deferUntilBlur
            ]

instance Aeson.FromJSON LiveFragmentRef where
    parseJSON = Aeson.withObject "LiveFragmentRef" \object ->
        LiveFragmentRef
            <$> object Aeson..: "fragmentKey"
            <*> object Aeson..: "targetId"
            <*> object Aeson..: "url"
            <*> object Aeson..: "deferUntilBlur"

instance Aeson.ToJSON LiveUpdateCommand where
    toJSON SubscribeLiveUpdates { scope, clientId } =
        Aeson.object
            [ "type" Aeson..= ("subscribe" :: Text)
            , "scope" Aeson..= scope
            , "clientId" Aeson..= clientId
            ]
    toJSON UnsubscribeLiveUpdates =
        Aeson.object ["type" Aeson..= ("unsubscribe" :: Text)]

instance Aeson.FromJSON LiveUpdateCommand where
    parseJSON = Aeson.withObject "LiveUpdateCommand" \object -> do
        messageType <- object Aeson..: "type"
        case (messageType :: Text) of
            "subscribe" ->
                SubscribeLiveUpdates
                    <$> object Aeson..: "scope"
                    <*> object Aeson..: "clientId"
            "unsubscribe" -> pure UnsubscribeLiveUpdates
            _ -> fail ("Unknown live update command: " <> cs messageType)

instance Aeson.ToJSON LiveUpdateMessage where
    toJSON LiveUpdatesSubscribed { scope } =
        Aeson.object
            [ "type" Aeson..= ("subscribed" :: Text)
            , "scope" Aeson..= scope
            ]
    toJSON LiveUpdatesInvalidated { scope, fragments, sourceClientId } =
        Aeson.object
            [ "type" Aeson..= ("invalidate" :: Text)
            , "scope" Aeson..= scope
            , "fragments" Aeson..= fragments
            , "sourceClientId" Aeson..= sourceClientId
            ]
    toJSON LiveUpdatesError { message } =
        Aeson.object
            [ "type" Aeson..= ("error" :: Text)
            , "message" Aeson..= message
            ]

data LiveSubscription = LiveSubscription
    { subscriptionId         :: !UUID.UUID
    , subscriptionScope      :: !LiveUpdateScope
    , subscriptionConnection :: !WebSocket.Connection
    }

liveSubscriptionsRef :: IORef [LiveSubscription]
liveSubscriptionsRef = unsafePerformIO (newIORef [])
{-# NOINLINE liveSubscriptionsRef #-}

registerLiveSubscription :: UUID.UUID -> LiveUpdateScope -> WebSocket.Connection -> IO ()
registerLiveSubscription subscriptionId scope connection =
    atomicModifyIORef' liveSubscriptionsRef \subscriptions ->
        ( LiveSubscription { subscriptionId, subscriptionScope = scope, subscriptionConnection = connection }
            : filter (\subscription -> subscription.subscriptionId /= subscriptionId) subscriptions
        , ()
        )

unregisterLiveSubscription :: UUID.UUID -> IO ()
unregisterLiveSubscription subscriptionId =
    atomicModifyIORef' liveSubscriptionsRef \subscriptions ->
        (filter (\subscription -> subscription.subscriptionId /= subscriptionId) subscriptions, ())

broadcastLiveInvalidation :: LiveUpdateScope -> Maybe Text -> [LiveFragmentRef] -> IO ()
broadcastLiveInvalidation scope sourceClientId fragments = do
    subscriptions <- readIORef liveSubscriptionsRef
    let matchingSubscriptions = filter (\subscription -> subscription.subscriptionScope == scope) subscriptions
    staleIds <- mapMaybeM (sendInvalidation scope sourceClientId fragments) matchingSubscriptions
    unless (null staleIds) do
        atomicModifyIORef' liveSubscriptionsRef \activeSubscriptions ->
            ( filter (\subscription -> subscription.subscriptionId `notElem` staleIds) activeSubscriptions
            , ()
            )

sendInvalidation :: LiveUpdateScope -> Maybe Text -> [LiveFragmentRef] -> LiveSubscription -> IO (Maybe UUID.UUID)
sendInvalidation scope sourceClientId fragments subscription = do
    result <-
        Exception.tryAny $
            WebSocket.sendTextData subscription.subscriptionConnection (Aeson.encode message)
    pure $
        case result of
            Left _  -> Just subscription.subscriptionId
            Right _ -> Nothing
    where
        message =
            LiveUpdatesInvalidated
                { scope
                , fragments
                , sourceClientId
                }

parseUuid :: Text -> Aeson.Parser UUID.UUID
parseUuid value =
    case UUID.fromText (Text.strip value) of
        Just uuid -> pure uuid
        Nothing   -> fail ("Invalid UUID: " <> cs value)

mapMaybeM :: (a -> IO (Maybe b)) -> [a] -> IO [b]
mapMaybeM action values =
    catMaybes <$> mapM action values
