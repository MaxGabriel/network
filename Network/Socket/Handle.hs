{-# LANGUAGE RecordWildCards #-}

module Network.Socket.Handle where

import Control.Concurrent.MVar
import qualified GHC.IO.Device (IODeviceType(Stream))
import GHC.IO.Handle.FD (fdToHandle')
import System.IO (IOMode(..), Handle, BufferMode(..), hSetBuffering)

import Network.Socket.Types

-- | Turns a Socket into an 'Handle'. By default, the new handle is
-- unbuffered. Use 'System.IO.hSetBuffering' to change the buffering.
--
-- Note that since a 'Handle' is automatically closed by a finalizer
-- when it is no longer referenced, you should avoid doing any more
-- operations on the 'Socket' after calling 'socketToHandle'.  To
-- close the 'Socket' after 'socketToHandle', call 'System.IO.hClose'
-- on the 'Handle'.

socketToHandle :: Socket -> IOMode -> IO Handle
socketToHandle s@Socket{..} mode =
 modifyMVar socketStatus $ \status ->
    if status == ConvertedToHandle
        then ioError (userError "socketToHandle: already a Handle")
        else do
    h <- fdToHandle' (fromIntegral socketFd) (Just GHC.IO.Device.Stream) True (show s) mode True{-bin-}
    hSetBuffering h NoBuffering
    return (ConvertedToHandle, h)
{-# DEPRECATED socketToHandle "Handle is not supported anymore" #-}
