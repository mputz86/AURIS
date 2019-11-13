{-# LANGUAGE
  TemplateHaskell
#-}
module GUI.TMFrameTab
  ( CLCWFluid(..)
  , TMFrameTabFluid(..)
  , TMFrameTab(..)
  , createTMFTab
  , tmfTabAddRow
  , setupCallbacks
  )
where

import           RIO
import qualified RIO.Text                      as T
import qualified Data.Text.Short               as ST
import qualified Data.Sequence                 as S
import           Control.Lens                   ( makeLenses )

import           Graphics.UI.FLTK.LowLevel.FLTKHS

import           Model.TMFrameModel
import           Model.ScrollingTableModel

import           GUI.TMFrameTable
import           GUI.ScrollingTable
import           GUI.Colors

import           Data.PUS.TMFrame
import           General.Hexdump



data CLCWFluid = CLCWFluid {
  _clcwfVCID :: Ref Output
  , _clcwfBitLock :: Ref Box
  , _clcwfNoRF :: Ref Box
  , _clcwfLockout :: Ref Box
  , _clcwfWait :: Ref Box
  , _clcwfRetransmit :: Ref Box
  , _clcwfReportVal :: Ref Output
  , _clcwfFarmB :: Ref Output
  , _clcwfGroup :: Ref Group
  }


data TMFrameTabFluid = TMFrameTabFluid {
  _tmffTabGroup :: Ref Group
  , _tmffHeaderGroup :: Ref Group
  , _tmffAddButton :: Ref Button
  , _tmffFrameTable :: Ref Group
  , _tmffFrameDetails :: Ref Group
  , _tmffGroupFrameDetails :: Ref Group
  , _tmffOutputSCID :: Ref Output
  , _tmffOutputVCID :: Ref Output
  , _tmffOutputOCF :: Ref Output
  , _tmffOutputVCFC :: Ref Output
  , _tmffOutputMCFC :: Ref Output
  , _tmffOutputFHP :: Ref Output
  , _tmffOutputSeg :: Ref Output
  , _tmffOutputDFH :: Ref Output
  , _tmffOutputOrder :: Ref Output
  , _tmffOutputSync :: Ref Output
  , _tmffGroupFrameDump :: Ref Group
  , _tmffDumpDisplay :: Ref TextDisplay
  , _tmffCLCW :: CLCWFluid
  }


data TMFrameTab = TMFrameTab {
  _tmfTabGroup :: Ref Group
  , _tmfHeaderGroup :: Ref Group
  , _tmfAddButton :: Ref Button
  , _tmfFrameTable :: Ref TableRow
  , _tmfFrameModel :: TMFrameModel
  , _tmfFrameDetails :: Ref Group
  , _tmfGroupFrameDetails :: Ref Group
  , _tmfOutputSCID :: Ref Output
  , _tmfOutputVCID :: Ref Output
  , _tmfOutputOCF :: Ref Output
  , _tmfOutputVCFC :: Ref Output
  , _tmfOutputMCFC :: Ref Output
  , _tmfOutputFHP :: Ref Output
  , _tmfOutputSeg :: Ref Output
  , _tmfOutputDFH :: Ref Output
  , _tmfOutputOrder :: Ref Output
  , _tmfOutputSync :: Ref Output
  , _tmfCLCW :: CLCWFluid
  , _tmfDump :: Ref TextDisplay
  , _tmfDumpBuffer :: Ref TextBuffer
  }
makeLenses ''TMFrameTab


tmfTabAddRow :: TMFrameTab -> TMFrame -> IO ()
tmfTabAddRow tab frame = do
  addRow (tab ^. tmfFrameTable) (tab ^. tmfFrameModel) frame


txtNoBitlock = "NO BITLOCK"
txtBitlock = "BITLOCK"

txtNoRF = "NO RF"
txtOkRF = "RF"

txtNoLockout = "NO LOCKOUT"
txtLockout = "LOCKOUT"

txtWait = "WAIT"
txtNoWait = "NO WAIT"

txtRetransmit = "RETRANSMIT"
txtNoRetransmit = "NO RETRANSMIT"

initCLCW :: CLCWFluid -> IO ()
initCLCW CLCWFluid {..} = do
  mcsGroupSetColor _clcwfGroup

  mcsOutputSetColor _clcwfVCID
  mcsOutputSetColor _clcwfReportVal
  mcsOutputSetColor _clcwfFarmB

  mcsBoxAlarm _clcwfBitLock txtNoBitlock
  mcsBoxAlarm _clcwfNoRF    txtNoRF
  mcsBoxAlarm _clcwfLockout txtLockout
  mcsBoxAlarm _clcwfWait    txtWait
  mcsBoxWarn _clcwfRetransmit txtRetransmit





createTMFTab :: TMFrameTabFluid -> IO TMFrameTab
createTMFTab TMFrameTabFluid {..} = do
  model <- tableModelNew
  table <- setupTable _tmffFrameTable model GUI.TMFrameTable.colDefinitions

  mcsGroupSetColor _tmffTabGroup
  mcsGroupSetColor _tmffHeaderGroup
  mcsGroupSetColor _tmffFrameDetails
  mcsGroupSetColor _tmffGroupFrameDetails
  mcsGroupSetColor _tmffGroupFrameDump

  mcsTextDisplaySetColor _tmffDumpDisplay
  buf <- textBufferNew Nothing Nothing
  setBuffer _tmffDumpDisplay (Just buf)


  mcsOutputSetColor _tmffOutputSCID
  mcsOutputSetColor _tmffOutputVCID
  mcsOutputSetColor _tmffOutputOCF
  mcsOutputSetColor _tmffOutputVCFC
  mcsOutputSetColor _tmffOutputMCFC
  mcsOutputSetColor _tmffOutputFHP
  mcsOutputSetColor _tmffOutputSeg
  mcsOutputSetColor _tmffOutputDFH
  mcsOutputSetColor _tmffOutputOrder
  mcsOutputSetColor _tmffOutputSync

  initCLCW _tmffCLCW

  pure TMFrameTab { _tmfTabGroup          = _tmffTabGroup
                  , _tmfHeaderGroup       = _tmffHeaderGroup
                  , _tmfAddButton         = _tmffAddButton
                  , _tmfFrameTable        = table
                  , _tmfFrameModel        = model
                  , _tmfFrameDetails      = _tmffFrameDetails
                  , _tmfGroupFrameDetails = _tmffGroupFrameDetails
                  , _tmfOutputSCID        = _tmffOutputSCID
                  , _tmfOutputVCID        = _tmffOutputVCID
                  , _tmfOutputOCF         = _tmffOutputOCF
                  , _tmfOutputVCFC        = _tmffOutputVCFC
                  , _tmfOutputMCFC        = _tmffOutputMCFC
                  , _tmfOutputFHP         = _tmffOutputFHP
                  , _tmfOutputSeg         = _tmffOutputSeg
                  , _tmfOutputDFH         = _tmffOutputDFH
                  , _tmfOutputOrder       = _tmffOutputOrder
                  , _tmfOutputSync        = _tmffOutputSync
                  , _tmfCLCW              = _tmffCLCW
                  , _tmfDump              = _tmffDumpDisplay
                  , _tmfDumpBuffer        = buf
                  }


tmfTabDetailsSetValues :: TMFrameTab -> TMFrame -> IO ()
tmfTabDetailsSetValues g frame = do
  void $ setValue (g ^. tmfOutputSCID)
                  (textDisplay (frame ^. tmFrameHdr . tmFrameScID))
  void $ setValue (g ^. tmfOutputVCID)
                  (textDisplay (frame ^. tmFrameHdr . tmFrameVcID))
  void $ setValue
    (g ^. tmfOutputOCF)
    (if frame ^. tmFrameHdr . tmFrameOpControl then "Y" else "N")
  void $ setValue (g ^. tmfOutputMCFC)
                  (textDisplay (frame ^. tmFrameHdr . tmFrameMCFC))
  void $ setValue (g ^. tmfOutputVCFC)
                  (textDisplay (frame ^. tmFrameHdr . tmFrameVCFC))
  void $ setValue (g ^. tmfOutputFHP) (displayFHP frame)
  void $ setValue (g ^. tmfOutputSeg)
                  (T.pack (show (frame ^. tmFrameHdr . tmFrameSegID)))
  void $ setValue (g ^. tmfOutputDFH)
                  (if frame ^. tmFrameHdr . tmFrameDfh then "Y" else "N")
  void $ setValue
    (g ^. tmfOutputOrder)
    (if frame ^. tmFrameHdr . tmFrameOrder then "REVERSE" else "FORWARD")
  void $ setValue
    (g ^. tmfOutputSync)
    (if frame ^. tmFrameHdr . tmFrameSync then "ASYNC" else "SYNC")

  setText (g ^. tmfDumpBuffer) (hexdumpBS (frame ^. tmFrameData))


setupCallbacks :: TMFrameTab -> IO ()
setupCallbacks window = do
  GUI.ScrollingTable.setupCallback (window ^. tmfFrameTable)
                                   (doubleClickTMF window)


doubleClickTMF :: TMFrameTab -> Row -> IO ()
doubleClickTMF window (Row row') = do
  res <- queryTableModel (window ^. tmfFrameModel) $ \s -> S.lookup row' s
  forM_ res (tmfTabDetailsSetValues window)
