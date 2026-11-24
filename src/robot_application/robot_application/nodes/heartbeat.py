"""
Example ROS2 node demonstrating constructor injection pattern.
"""

from rclpy.node import Node

from robot_application.services.heartbeat import HeartbeatService


class HeartbeatNode(Node):
    def __init__(
        self, 
        service: HeartbeatService,
        period: float = 1.0
    ) -> None:
        super().__init__("heartbeat")

        self._service = service

        self._timer = self.create_timer(period, self._heartbeat)

    def _heartbeat(self) -> None:
        count = self.service.tick()
        self.get_logger().info(f"Heartbeat {count}")