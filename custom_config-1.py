from genrl.communication.hivemind.hivemind_backend import HivemindBackend, HivemindRendezvouz
from hivemind.dht import DHT
from hivemind.p2p import P2PDaemonError
import os
import logging
from typing import List, Optional

# Logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class CustomHivemindBackend(HivemindBackend):
    def __init__(self, initial_peers: Optional[List[str]] = None, timeout: int = 600, 
                 disable_caching: bool = False, beam_size: int = 1000, **kwargs):
        
        # Basic
        self.world_size = int(os.environ.get("HIVEMIND_WORLD_SIZE", 1))
        self.timeout = timeout
        self.bootstrap = HivemindRendezvouz.is_bootstrap()
        self.beam_size = beam_size
        self.dht = None

        if disable_caching:
            kwargs["cache_locally"] = False
            kwargs["cache_on_store"] = False

        try:
            logger.info("Attempting to create DHT with custom configuration...")
            
            if self.bootstrap:
                self.dht = DHT(
                    start=True,
                    host_maddrs=['/ip4/0.0.0.0/tcp/4001'],
                    announce_maddrs=['/ip4/IP/tcp/443'],  # Replace IP
                    initial_peers=initial_peers,
                    **kwargs,
                )
                dht_maddrs = self.dht.get_visible_maddrs(latest=True)
                HivemindRendezvouz.set_initial_peers(dht_maddrs)
            else:
                initial_peers = initial_peers or HivemindRendezvouz.get_initial_peers()
                self.dht = DHT(
                    start=True,
                    host_maddrs=['/ip4/0.0.0.0/tcp/4001'],
                    announce_maddrs=['/ip4/IP/tcp/443'],  # Replace IP
                    initial_peers=initial_peer,
                    **kwargs,
                )
                
            logger.info("DHT created successfully!")
            
        except P2PDaemonError as e:
            logger.error(f"P2P Daemon failed to start: {e}")
            # Without Initial Peers
            logger.info("Retrying without initial peers...")
            try:
                if self.bootstrap:
                    self.dht = DHT(
                        start=True,
                        host_maddrs=['/ip4/0.0.0.0/tcp/4001'],
                        announce_maddrs=['/ip4/IP/tcp/443'],      # Replace IP
                        initial_peers=None,  # No bootstrap peers
                        **kwargs,
                    )
                else:
                    self.dht = DHT(
                        start=True,
                        host_maddrs=['/ip4/0.0.0.0/tcp/4001'],
                        announce_maddrs=['/ip4/IP/tcp/443'],      # Replace IP
                        initial_peers=None,  # No bootstrap peers
                        **kwargs,
                    )
                logger.info("DHT started successfully without bootstrap peers!")
            except Exception as retry_error:
                logger.error(f"Failed even without bootstrap peers: {retry_error}")
                raise
        except Exception as e:
            logger.error(f"Unexpected error creating DHT: {e}")
            raise
