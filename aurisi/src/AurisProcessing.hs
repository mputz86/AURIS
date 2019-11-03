{-# LANGUAGE
    OverloadedStrings
    , BangPatterns
    , NoImplicitPrelude
#-}
module AurisProcessing
  ( runProcessing
  )
where

import           RIO
import qualified RIO.Text                      as T

import           Conduit
import           Data.Conduit.Network
import           Conduit.SocketConnector

import           Data.PUS.GlobalState
import           Data.PUS.MissionSpecific.Definitions
import           Data.PUS.TMFrameExtractor
import           Data.PUS.TMPacketProcessing
import           Data.PUS.NcduToTMFrame
import           Protocol.NCTRS
import           Protocol.ProtocolInterfaces
import           Control.PUS.Classes

import           Interface.Interface
import           Interface.Events

import           AurisConfig

import           Data.DataModel
import           Data.MIB.LoadMIB

import           System.Directory               
import           System.FilePath


configPath :: FilePath 
configPath = ".config/AURISi"


defaultMIBFile :: FilePath
defaultMIBFile = configPath </> "data_model.raw"




runProcessing
  :: AurisConfig -> PUSMissionSpecific -> Maybe FilePath -> Interface -> IO ()
runProcessing cfg missionSpecific mibPath interface = do
  defLogOptions <- logOptionsHandle stdout True
  let logOptions = setLogMinLevel (convLogLevel (aurisLogLevel cfg)) defLogOptions
  withLogFunc logOptions $ \logFunc -> do
    state <- newGlobalState (aurisPusConfig cfg)
                            missionSpecific
                            logFunc
                            (ifRaiseEvent interface . EventPUS)

    runRIO state $ do
      -- first, try to load a data model or import a MIB
      model <- loadDataModel mibPath
      var   <- view getDataModel
      atomically $ writeTVar var model

      runTMChain cfg
    pure ()


runTMChain :: AurisConfig -> RIO GlobalState ()
runTMChain cfg = do
  let chain =
        receiveTmNcduC
          .| ncduToTMFrameC
          .| storeFrameC
          .| tmFrameExtraction IF_NCTRS
          .| packetProcessorC
          .| raiseTMPacketC

      ignoreConduit = awaitForever $ \_ -> pure ()

  runGeneralTCPReconnectClient
      (clientSettings (aurisNctrsTMPort cfg) (encodeUtf8 (aurisNctrsHost cfg)))
      200000
    $ do
        \app -> void $ runConduitRes (appSource app .| chain .| ignoreConduit)
        -- \app -> void $ concurrently
        --   (runConduitRes (chain .| appSink app)-}
        --  return ())
        -- (runConduitRes (appSource app .| chain .| ignoreConduit))




loadDataModel
  :: (MonadUnliftIO m, MonadReader env m, HasLogFunc env)
  => Maybe FilePath
  -> m DataModel
loadDataModel opts = do 
  home <- liftIO $ getHomeDirectory
  case opts of
    Just str -> do
      res <- loadMIB str
      case res of
        Left err -> do
          logError $ display ("Error on importing MIB: " :: Text) <> display err
          return Data.DataModel.empty
        Right model -> do
          logInfo $ display ("Successfully imported MIB." :: Text)
          liftIO $ createDirectoryIfMissing True (home </> configPath)
          writeDataModel (home </> defaultMIBFile) model
          return model
    Nothing -> do
      let path = home </> defaultMIBFile
      ex <- liftIO $ doesFileExist path
      if ex
        then do
          res <- readDataModel path
          case res of
            Left err -> do
              logError
                $  display ("Error loading data model from " :: Text)
                <> display (T.pack path)
                <> display (": " :: Text)
                <> display err
              return Data.DataModel.empty
            Right model -> do
              logInfo $ display ("Successfully loaded data model" :: Text)
              return model
        else do
          logInfo
            $  display ("Data model file '" :: Text)
            <> display (T.pack path)
            <> display ("' does not exist." :: Text)
          return Data.DataModel.empty
