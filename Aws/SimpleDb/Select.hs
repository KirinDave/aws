{-# LANGUAGE RecordWildCards, MultiParamTypeClasses, FlexibleInstances, FlexibleContexts #-}

module Aws.SimpleDb.Select
where

import           Aws.Query
import           Aws.SimpleDb.Error
import           Aws.SimpleDb.Info
import           Aws.SimpleDb.Model
import           Aws.SimpleDb.Response
import           Aws.Transaction
import           Control.Monad.Compose.Class
import           Text.XML.Monad
import qualified Control.Failure             as F

data Select
    = Select {
        sSelectExpression :: String
      , sConsistentRead :: Bool
      , sNextToken :: String
      }
    deriving (Show)

data SelectResponse
    = SelectResponse {
        srItems :: [Item [Attribute String]]
      , srNextToken :: Maybe String
      }
    deriving (Show)

select :: String -> Select
select expr = Select { sSelectExpression = expr, sConsistentRead = False, sNextToken = "" }

instance AsQuery Select SdbInfo where
    asQuery i Select{..}
        = addQuery [("Action", "Select"), ("SelectExpression", sSelectExpression)]
          . addQueryIf sConsistentRead [("ConsistentRead", awsTrue)]
          . addQueryUnless (null sNextToken) [("NextToken", sNextToken)]
          $ sdbiBaseQuery i

instance SdbFromResponse SelectResponse where
    sdbFromResponse = do
      testElementNameUI "SelectResponse"
      items <- inList readItem <<< findElementsNameUI "Item"
      nextToken <- tryMaybe $ strContent <<< findElementNameUI "NextToken"
      return $ SelectResponse items nextToken
        where readItem = do
                name <- strContent <<< findElementNameUI "Name"
                attributes <- inList readAttribute <<< findElementsNameUI "Attribute"
                return $ Item name attributes
              readAttribute = do
                name <- strContent <<< findElementNameUI "Name"
                value <- strContent <<< findElementNameUI "Value"
                return $ ForAttribute name value

instance Transaction Select SdbInfo (SdbResponse SelectResponse)
