{-# LANGUAGE
    DeriveGeneric
    , NoImplicitPrelude
    , TemplateHaskell
#-}
module Data.PUS.TCRequest
    ( TCRequest(..)
    , tcReqRequestID
    , tcReqMAPID
    , tcReqSCID
    , tcReqVCID
    , tcReqTransMode
    )
where

import           RIO

import           Control.Lens                   ( makeLenses )

import           Data.Binary
import           Data.Aeson

import           Data.PUS.Types


data TCRequest = TCRequest {
    _tcReqRequestID :: RequestID
    , _tcReqMAPID :: MAPID
    , _tcReqSCID :: SCID
    , _tcReqVCID :: VCID
    , _tcReqTransMode :: TransmissionMode
    }
    deriving (Eq, Show, Read, Generic)

makeLenses ''TCRequest


instance Binary TCRequest
instance FromJSON TCRequest
instance ToJSON TCRequest where
    toEncoding = genericToEncoding defaultOptions



