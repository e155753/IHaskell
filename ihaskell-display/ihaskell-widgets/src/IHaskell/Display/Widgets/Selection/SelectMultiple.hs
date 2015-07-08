{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeSynonymInstances #-}

module IHaskell.Display.Widgets.Selection.SelectMultiple (
-- * The SelectMultiple Widget
SelectMultipleWidget, 
                      -- * Constructor
                      mkSelectMultipleWidget) where

-- To keep `cabal repl` happy when running from the ihaskell repo
import           Prelude

import           Control.Monad (fmap, join, sequence)
import           Data.Aeson
import qualified Data.HashMap.Strict as HM
import           Data.IORef (newIORef)
import           Data.Text (Text)
import qualified Data.Vector as V
import           Data.Vinyl (Rec(..), (<+>))

import           IHaskell.Display
import           IHaskell.Eval.Widgets
import           IHaskell.IPython.Message.UUID as U

import           IHaskell.Display.Widgets.Types
import           IHaskell.Display.Widgets.Common

-- | A 'SelectMultipleWidget' represents a SelectMultiple widget from IPython.html.widgets.
type SelectMultipleWidget = IPythonWidget SelectMultipleType

-- | Create a new SelectMultiple widget
mkSelectMultipleWidget :: IO SelectMultipleWidget
mkSelectMultipleWidget = do
  -- Default properties, with a random uuid
  uuid <- U.random
  let widgetState = WidgetState $ defaultMultipleSelectionWidget "SelectMultipleView"

  stateIO <- newIORef widgetState

  let widget = IPythonWidget uuid stateIO
      initData = object
                   [ "model_name" .= str "WidgetModel"
                   , "widget_class" .= str "IPython.SelectMultiple"
                   ]

  -- Open a comm for this widget, and store it in the kernel state
  widgetSendOpen widget initData $ toJSON widgetState

  -- Return the widget
  return widget

-- | Artificially trigger a selection
triggerSelection :: SelectMultipleWidget -> IO ()
triggerSelection widget = join $ getField widget SSelectionHandler

instance IHaskellDisplay SelectMultipleWidget where
  display b = do
    widgetSendView b
    return $ Display []

instance IHaskellWidget SelectMultipleWidget where
  getCommUUID = uuid
  comm widget (Object dict1) _ = do
    let key1 = "sync_data" :: Text
        key2 = "selected_labels" :: Text
        Just (Object dict2) = HM.lookup key1 dict1
        Just (Array labels) = HM.lookup key2 dict2
        labelList = map (\(String x) -> x) $ V.toList labels
    opts <- getField widget SOptions
    case opts of
      OptionLabels _ -> do
        setField' widget SSelectedLabels labelList
        setField' widget SSelectedValues labelList
      OptionDict ps ->
        case sequence $ map (`lookup` ps) labelList of
          Nothing -> return ()
          Just valueList -> do
            setField' widget SSelectedLabels labelList
            setField' widget SSelectedValues valueList
    triggerSelection widget
