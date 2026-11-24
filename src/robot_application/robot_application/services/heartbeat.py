"""
Simple example of an application service.

Best practices keep non-ROS2 application logic implementation
outside ROS2 nodes and injects these dependencies into nodes
as needed. 
"""

class HeartbeatService:
    def __init__(self) -> None:
        self._counter = 0

    def tick(self) -> int:
        self._counter += 1
        return self._counter