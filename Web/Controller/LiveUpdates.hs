module Web.Controller.LiveUpdates where

import Application.Helper.Controller
import Application.Helper.LiveUpdate
import qualified Data.Aeson as Aeson
import qualified Data.ByteString.Lazy as LByteString
import qualified Data.UUID as UUID
import qualified Data.UUID.V4 as UUIDv4
import qualified Network.WebSockets as WebSocket
import Web.Controller.Prelude

instance WSApp LiveUpdatesWSApp where
    initialState = AwaitingSubscription

    run = do
        ensureIsUser
        ensureCurrentVenue
        ensureProfileCompleted

        forever do
            message <- receiveData @LByteString.ByteString
            case Aeson.decode message of
                Nothing ->
                    sendJSON
                        LiveUpdatesError
                            { message = "Could not decode live update command"
                            }
                Just command ->
                    handleCommand command

    onClose = do
        getState >>= \case
            LiveUpdatesConnected { subscriptionId } ->
                unregisterLiveSubscription subscriptionId
            AwaitingSubscription ->
                pure ()

handleCommand ::
    ( ?state :: IORef LiveUpdatesWSApp
    , ?connection :: WebSocket.Connection
    , ?context :: ControllerContext
    , ?modelContext :: ModelContext
    ) =>
    LiveUpdateCommand ->
    IO ()
handleCommand command =
    case command of
        SubscribeLiveUpdates { scope } -> do
            authorized <- isAuthorizedScope scope
            if authorized
                then do
                    unregisterCurrentSubscription
                    subscriptionId <- UUIDv4.nextRandom
                    registerLiveSubscription subscriptionId scope ?connection
                    setState LiveUpdatesConnected { subscriptionId }
                    sendJSON LiveUpdatesSubscribed { scope }
                else
                    sendJSON
                        LiveUpdatesError
                            { message = "Not authorized for requested live update scope"
                            }
        UnsubscribeLiveUpdates -> do
            unregisterCurrentSubscription
            setState AwaitingSubscription

unregisterCurrentSubscription ::
    (?state :: IORef LiveUpdatesWSApp) =>
    IO ()
unregisterCurrentSubscription =
    getState >>= \case
        LiveUpdatesConnected { subscriptionId } ->
            unregisterLiveSubscription subscriptionId
        AwaitingSubscription ->
            pure ()

isAuthorizedScope ::
    (?context :: ControllerContext, ?modelContext :: ModelContext) =>
    LiveUpdateScope ->
    IO Bool
isAuthorizedScope RosterWeekScope { venueId, weekOffset } = do
    if venueId /= unpackId currentVenueId
        then pure False
        else do
            let _ = weekOffset
            pure True
