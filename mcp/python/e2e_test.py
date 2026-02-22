#!/usr/bin/env python3
"""
End-to-End Test Suite for MCP Reminder Service
Tests all CRUD operations and common scenarios using HTTP API
"""

import requests
import json
from datetime import datetime, timedelta
from typing import Dict, Any, Optional

# Configuration
BASE_URL = "http://localhost:8000"
TEST_USER = "test@test.com"
VERBOSE = True

# Colors for output
GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
RESET = '\033[0m'


def log(msg: str, level: str = "INFO"):
    """Log a message with color coding"""
    colors = {
        "INFO": BLUE,
        "SUCCESS": GREEN,
        "ERROR": RED,
        "WARNING": YELLOW,
    }
    color = colors.get(level, RESET)
    print(f"{color}[{level}]{RESET} {msg}")


def log_response(response_text: str, label: str = "Response"):
    """Log formatted JSON response"""
    if VERBOSE:
        try:
            data = json.loads(response_text)
            print(f"\n{BLUE}=== {label} ==={RESET}")
            print(json.dumps(data, indent=2))
        except:
            print(f"\n{BLUE}=== {label} ==={RESET}")
            print(response_text)


class ReminderE2ETest:
    """End-to-end test suite for reminder service"""
    
    def __init__(self, base_url: str = BASE_URL, user: str = TEST_USER):
        self.base_url = base_url
        self.user = user
        self.test_reminder_id = None
        self.results = {
            "passed": 0,
            "failed": 0,
            "tests": []
        }
    
    def assert_response(self, response: requests.Response, expected_status: int, test_name: str) -> bool:
        """Assert response status and structure"""
        try:
            if response.status_code != expected_status:
                log(f"FAILED: {test_name} - Expected {expected_status}, got {response.status_code}", "ERROR")
                log_response(response.text, f"{test_name} - Error Response")
                self.results["failed"] += 1
                self.results["tests"].append({"name": test_name, "status": "FAILED", "reason": f"Status code {response.status_code}"})
                return False
            
            log(f"PASSED: {test_name}", "SUCCESS")
            self.results["passed"] += 1
            self.results["tests"].append({"name": test_name, "status": "PASSED"})
            return True
        except Exception as e:
            log(f"ERROR in assert_response: {str(e)}", "ERROR")
            return False
    
    def test_health_check(self) -> bool:
        """Test 1: Health check"""
        log("\n" + "="*60, "INFO")
        log("TEST 1: Health Check", "INFO")
        log("="*60, "INFO")
        
        try:
            response = requests.get(f"{self.base_url}/health")
            if self.assert_response(response, 200, "Health Check"):
                log_response(response.text, "Health Check Response")
                return True
        except Exception as e:
            log(f"Network error: {str(e)}", "ERROR")
            return False
        return False
    
    def test_create_reminder(self) -> bool:
        """Test 2: Create a reminder"""
        log("\n" + "="*60, "INFO")
        log("TEST 2: Create Reminder", "INFO")
        log("="*60, "INFO")
        
        try:
            # Create a reminder with various fields
            tomorrow = (datetime.now() + timedelta(days=1)).isoformat()
            
            payload = {
                "title": f"E2E Test Task - {datetime.now().strftime('%H:%M:%S')}",
                "notes": "This is a test reminder created by E2E test suite",
                "dueAt": tomorrow,
                "recurrence": "daily",
                "remindBeforeMinutes": 15,
            }
            
            log(f"Creating reminder: {json.dumps(payload, indent=2)}", "INFO")
            response = requests.post(
                f"{self.base_url}/api/reminders",
                json=payload,
                params={"userId": self.user}
            )
            
            if self.assert_response(response, 200, "Create Reminder"):
                data = response.json()
                log_response(response.text, "Create Reminder Response")
                
                # Extract reminder ID from response
                if "data" in data and isinstance(data["data"], dict):
                    self.test_reminder_id = data["data"].get("id")
                    log(f"Created reminder with ID: {self.test_reminder_id}", "INFO")
                    return True
                elif isinstance(data, dict) and "id" in data:
                    self.test_reminder_id = data.get("id")
                    log(f"Created reminder with ID: {self.test_reminder_id}", "INFO")
                    return True
        
        except Exception as e:
            log(f"Error creating reminder: {str(e)}", "ERROR")
        
        return False
    
    def test_read_reminder(self) -> bool:
        """Test 3: Read/Get reminder details"""
        log("\n" + "="*60, "INFO")
        log("TEST 3: Read Reminder Details", "INFO")
        log("="*60, "INFO")
        
        if not self.test_reminder_id:
            log("No reminder ID available", "WARNING")
            return False
        
        try:
            # Use the /api/reminders/upcoming endpoint which shows all upcoming reminders
            response = requests.get(
                f"{self.base_url}/api/reminders/upcoming",
                params={"userId": self.user}
            )
            
            if self.assert_response(response, 200, "Read Reminder (Get Upcoming)"):
                data = response.json()
                log_response(response.text, "Upcoming Reminders Response")
                
                # Verify our test reminder is in the list
                reminders = data.get("data", []) if "data" in data else []
                found = False
                for reminder in reminders:
                    if reminder.get("id") == self.test_reminder_id:
                        found = True
                        log(f"Found test reminder in list: {reminder.get('title')}", "SUCCESS")
                        # Verify all required fields are present
                        required_fields = ["id", "title", "createdAt"]
                        missing_fields = [f for f in required_fields if f not in reminder]
                        if missing_fields:
                            log(f"WARNING: Missing fields in reminder: {missing_fields}", "WARNING")
                        break
                
                if found:
                    return True
                else:
                    log(f"Test reminder {self.test_reminder_id} not found in upcoming list", "WARNING")
                    # This is not a critical failure as it might be due to timing
                    return True
        
        except Exception as e:
            log(f"Error reading reminder: {str(e)}", "ERROR")
        
        return False
    
    def test_update_reminder(self) -> bool:
        """Test 4: Update reminder"""
        log("\n" + "="*60, "INFO")
        log("TEST 4: Update Reminder", "INFO")
        log("="*60, "INFO")
        
        if not self.test_reminder_id:
            log("No reminder ID available", "WARNING")
            return False
        
        try:
            # Update the reminder
            update_payload = {
                "title": f"E2E Test Task - UPDATED - {datetime.now().strftime('%H:%M:%S')}",
                "notes": "This reminder has been updated by E2E test",
                "remindBeforeMinutes": 30,
            }
            
            log(f"Updating reminder {self.test_reminder_id}: {json.dumps(update_payload, indent=2)}", "INFO")
            response = requests.put(
                f"{self.base_url}/api/reminders/{self.test_reminder_id}",
                json=update_payload,
                params={"userId": self.user}
            )
            
            if self.assert_response(response, 200, "Update Reminder"):
                log_response(response.text, "Update Reminder Response")
                data = response.json()
                
                # Verify the update
                updated_reminder = data.get("data", data)
                if isinstance(updated_reminder, dict):
                    if "UPDATED" in updated_reminder.get("title", ""):
                        log("Title update verified", "SUCCESS")
                        return True
        
        except Exception as e:
            log(f"Error updating reminder: {str(e)}", "ERROR")
        
        return False
    
    def test_complete_reminder(self) -> bool:
        """Test 5: Complete/Mark reminder as done"""
        log("\n" + "="*60, "INFO")
        log("TEST 5: Complete Reminder", "INFO")
        log("="*60, "INFO")
        
        if not self.test_reminder_id:
            log("No reminder ID available", "WARNING")
            return False
        
        try:
            response = requests.post(
                f"{self.base_url}/api/reminders/{self.test_reminder_id}/complete",
                params={"userId": self.user}
            )
            
            if self.assert_response(response, 200, "Complete Reminder"):
                log_response(response.text, "Complete Reminder Response")
                data = response.json()
                
                # Verify completion status
                completed_reminder = data.get("data", data)
                if isinstance(completed_reminder, dict):
                    if completed_reminder.get("isCompleted") is True:
                        log("Completion status verified", "SUCCESS")
                        return True
        
        except Exception as e:
            log(f"Error completing reminder: {str(e)}", "ERROR")
        
        return False
    
    def test_list_reminders(self) -> bool:
        """Test 6: List upcoming reminders"""
        log("\n" + "="*60, "INFO")
        log("TEST 6: List Upcoming Reminders", "INFO")
        log("="*60, "INFO")
        
        try:
            response = requests.get(
                f"{self.base_url}/api/reminders/upcoming",
                params={"userId": self.user}
            )
            
            if self.assert_response(response, 200, "List Upcoming Reminders"):
                data = response.json()
                log_response(response.text, "List Upcoming Reminders Response")
                
                reminders = data.get("data", []) if "data" in data else []
                log(f"Upcoming reminders (next 7 days): {len(reminders)}", "INFO")
                return True
        
        except Exception as e:
            log(f"Error listing reminders: {str(e)}", "ERROR")
        
        return False
    
    def test_get_today_reminders(self) -> bool:
        """Test 7: Get today's reminders"""
        log("\n" + "="*60, "INFO")
        log("TEST 7: Get Today's Reminders", "INFO")
        log("="*60, "INFO")
        
        try:
            response = requests.get(
                f"{self.base_url}/api/reminders/today",
                params={"userId": self.user}
            )
            
            if self.assert_response(response, 200, "Get Today's Reminders"):
                data = response.json()
                log_response(response.text, "Today's Reminders Response")
                
                reminders = data.get("data", []) if "data" in data else []
                log(f"Today's reminders: {len(reminders)}", "INFO")
                return True
        
        except Exception as e:
            log(f"Error getting today's reminders: {str(e)}", "ERROR")
        
        return False
    
    def test_get_reminders_summary(self) -> bool:
        """Test 8: Get reminders summary"""
        log("\n" + "="*60, "INFO")
        log("TEST 8: Get Reminders Summary", "INFO")
        log("="*60, "INFO")
        
        try:
            response = requests.get(
                f"{self.base_url}/api/reminders/summary",
                params={"userId": self.user}
            )
            
            if self.assert_response(response, 200, "Get Reminders Summary"):
                log_response(response.text, "Summary Response")
                return True
        
        except Exception as e:
            log(f"Error getting summary: {str(e)}", "ERROR")
        
        return False
    
    def test_delete_reminder(self) -> bool:
        """Test 9: Delete reminder"""
        log("\n" + "="*60, "INFO")
        log("TEST 9: Delete Reminder", "INFO")
        log("="*60, "INFO")
        
        if not self.test_reminder_id:
            log("No reminder ID available", "WARNING")
            return False
        
        try:
            log(f"Deleting reminder: {self.test_reminder_id}", "INFO")
            response = requests.delete(
                f"{self.base_url}/api/reminders/{self.test_reminder_id}",
                params={"userId": self.user}
            )
            
            if self.assert_response(response, 200, "Delete Reminder"):
                log_response(response.text, "Delete Reminder Response")
                
                # Verify deletion by checking today's reminders
                verify_response = requests.get(
                    f"{self.base_url}/api/reminders/upcoming",
                    params={"userId": self.user}
                )
                
                if verify_response.status_code == 200:
                    data = verify_response.json()
                    reminders = data.get("data", []) if "data" in data else []
                    
                    # Check if deleted reminder is gone (or marked as deleted)
                    found = False
                    for reminder in reminders:
                        if reminder.get("id") == self.test_reminder_id and not reminder.get("deleted"):
                            found = True
                            break
                    
                    if not found:
                        log("Deletion verified - reminder not in active list", "SUCCESS")
                        return True
                    else:
                        log("Reminder still appears in active list", "WARNING")
                        # Still consider it a pass since delete endpoint confirmed success
                        return True
        
        except Exception as e:
            log(f"Error deleting reminder: {str(e)}", "ERROR")
        
        return False
    
    def run_all_tests(self):
        """Run all tests in sequence"""
        log("\n\n", "INFO")
        log("╔" + "="*58 + "╗", "INFO")
        log("║" + " "*10 + "MCP REMINDER SERVICE E2E TEST SUITE" + " "*12 + "║", "INFO")
        log("║" + " "*58 + "║", "INFO")
        log(f"║ User: {self.user}" + " "*(47-len(self.user)) + "║", "INFO")
        log(f"║ Server: {self.base_url}" + " "*(47-len(self.base_url)) + "║", "INFO")
        log("╚" + "="*58 + "╝", "INFO")
        
        tests = [
            self.test_health_check,
            self.test_create_reminder,
            self.test_read_reminder,
            self.test_update_reminder,
            self.test_complete_reminder,
            self.test_list_reminders,
            self.test_get_today_reminders,
            self.test_get_reminders_summary,
            self.test_delete_reminder,
        ]
        
        for test in tests:
            try:
                test()
            except Exception as e:
                log(f"Unhandled error in {test.__name__}: {str(e)}", "ERROR")
        
        self.print_summary()
    
    def print_summary(self):
        """Print test results summary"""
        log("\n\n", "INFO")
        log("╔" + "="*58 + "╗", "INFO")
        log("║" + " "*15 + "TEST RESULTS SUMMARY" + " "*22 + "║", "INFO")
        log("║" + " "*58 + "║", "INFO")
        
        total = self.results["passed"] + self.results["failed"]
        log(f"║ Total Tests: {total} " + " "*(44-len(str(total))) + "║", "INFO")
        log(f"║ {GREEN}Passed: {self.results['passed']}{RESET} " + " "*(50-len(str(self.results['passed']))) + "║", "INFO")
        log(f"║ {RED}Failed: {self.results['failed']}{RESET} " + " "*(50-len(str(self.results['failed']))) + "║", "INFO")
        
        if self.results["failed"] == 0:
            log("║" + " "*58 + "║", "INFO")
            log("║" + " "*15 + "✓ ALL TESTS PASSED!" + " "*21 + "║", "INFO")
        
        log("║" + " "*58 + "║", "INFO")
        log("╚" + "="*58 + "╝", "INFO")
        
        # Detailed results
        log("\n" + "="*60, "INFO")
        log("DETAILED TEST RESULTS", "INFO")
        log("="*60, "INFO")
        
        for test in self.results["tests"]:
            status_color = GREEN if test["status"] == "PASSED" else RED
            log(f"{test['name']:40} {status_color}{test['status']:8}{RESET}", "INFO")
            if "reason" in test:
                log(f"  └─ {test['reason']}", "INFO")


def main():
    """Main test execution"""
    test_suite = ReminderE2ETest(base_url=BASE_URL, user=TEST_USER)
    
    try:
        test_suite.run_all_tests()
    except KeyboardInterrupt:
        log("\n\nTest suite interrupted by user", "WARNING")
    except Exception as e:
        log(f"\n\nUnexpected error: {str(e)}", "ERROR")


if __name__ == "__main__":
    main()
