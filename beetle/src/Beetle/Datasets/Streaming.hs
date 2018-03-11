{-# LANGUAGE MultiParamTypeClasses #-}

module Beetle.Datasets.Streaming where

import qualified Streaming.Prelude as S
import Streaming.Prelude (Stream, Of)
import qualified Data.ByteString.Streaming as SBS
import Streaming.Cassava
import Numeric.Datasets
import Control.Monad.IO.Class
import Data.Maybe
import System.IO.Error (userError)
import Control.Monad.Error.Class (throwError)

unCsvException :: CsvParseException -> String
unCsvException (CsvParseException s) = s

streamDataset :: Dataset a -> Stream (Of (Either String a)) IO ()
streamDataset ds = do
  dir <- liftIO $ tempDirForDataset ds
  lbs <- liftIO $ fmap (fromMaybe id $ preProcess ds) $ getFileFromSource dir $ source ds
  readStreamDataset (readAs ds) $ SBS.fromLazy lbs

readStreamDataset :: ReadAs a -> SBS.ByteString IO () -> Stream (Of (Either String a)) IO ()
readStreamDataset (CSVRecord hhdr opts) sbs
  = fmap (const ()) $ S.map (either (Left . unCsvException) Right) $ decodeWithErrors opts hhdr sbs
readStreamDataset _ _ = throwError $ userError "readStreamDataset: only CSVRecord implemented "

foldDataset :: Dataset a -> b -> (b -> Either String a -> IO b) -> IO b
foldDataset ds x0 accf  = do
  let s = streamDataset ds
  S.foldM_ accf (return x0) (return) s

mapDataset_ :: Dataset a -> (Either String a -> IO ()) -> IO ()
mapDataset_ ds f = foldDataset ds () (\() x -> f x)