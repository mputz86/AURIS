{-# LANGUAGE OverloadedStrings
    , BangPatterns
    , GeneralizedNewtypeDeriving
    , DeriveGeneric
    , RecordWildCards
    , NoImplicitPrelude
    , BinaryLiterals
    , NumericUnderscores
    , FlexibleInstances
    , GADTs
    , ExistentialQuantification
#-}
module Data.PUS.TMParameterExtraction
  ( extractExtParameters
  , extParamToParVal
  )
where

import           RIO

import           Control.Lens                   ( (.~) )

import           Data.Text.Short               as T

import           General.Types
import           General.Time

import           Data.PUS.Parameter
import           Data.PUS.Value
import           Data.PUS.EncTime

import           Data.TM.Parameter
import           Data.TM.Value
import           Data.TM.Validity



extParamToParVal :: SunTime -> Epoch -> Validity -> ExtParameter -> TMParameter
extParamToParVal timestamp epoch validity ExtParameter {..} = TMParameter
  { _pName     = T.fromText _extParName
  , _pTime     = timestamp
  , _pValue    = valueToTMValue epoch validity _extParValue
  , _pEngValue = Nothing
  }

valueToTMValue :: Epoch -> Validity -> Value -> TMValue
valueToTMValue _ validity (ValUInt3 x) =
  TMValue (TMValUInt (fromIntegral x)) validity
valueToTMValue _ validity (ValInt8 x) =
  TMValue (TMValInt (fromIntegral x)) validity
valueToTMValue _ validity (ValInt16 _ x) =
  TMValue (TMValInt (fromIntegral x)) validity
valueToTMValue _ validity (ValDouble _ x) = TMValue (TMValDouble x) validity
valueToTMValue _ validity (ValString x       ) = checkString validity x
valueToTMValue _ validity (ValFixedString _ x) = checkString validity x
valueToTMValue _ validity (ValOctet x        ) = TMValue (TMValOctet x) validity
valueToTMValue _ validity (ValFixedOctet _ x ) = TMValue (TMValOctet x) validity
valueToTMValue epoch validity (ValCUCTime x) =
  let t = cucTimeToSunTime epoch x in TMValue (TMValTime t) validity
valueToTMValue _ validity ValUndefined =
  TMValue (TMValUInt 0) (setUndefinedValue validity)



checkString :: Validity -> ByteString -> TMValue
checkString validity x = case T.fromByteString x of
  Just s  -> TMValue (TMValString s) validity
  Nothing -> TMValue (TMValString T.empty) (setStringNotUtf8 validity)


extractExtParameters :: ByteString -> [ExtParameter] -> [Parameter]
extractExtParameters bytes = map (extParamToParam . getExtParameter' bytes)




getExtParameter' :: ByteString -> ExtParameter -> ExtParameter
getExtParameter' bytes param =
  let (bo, BitOffset bits) = offsetParts off
      bitOffset            = param ^. extParOff
      off                  = toOffset bitOffset
      value                = param ^. extParValue
  in  if bits == 0 && isSetableAligned value
        then param & extParValue .~ getAlignedValue bytes bo value
        else if isGettableUnaligned value
          then param & extParValue .~ getUnalignedValue bytes off value
          else
                     -- in this case, we go to the next byte offset. According
                     -- to PUS, we cannot set certain values on non-byte boundaries
            let newOffset = nextByteAligned bitOffset
                newParam  = param & extParOff .~ newOffset
            in  getExtParameter' bytes newParam

