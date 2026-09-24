"""Pydantic request schemas — strict validation on all incoming payloads."""

from datetime import date
from typing import Dict, Literal

from pydantic import BaseModel, Field, field_validator, model_validator


class AttendanceMarkRequest(BaseModel):
    student_id: int
    status: Literal["Present", "Absent"]


class AssignmentCreateRequest(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    due_date: date
    max_marks: int = Field(..., gt=0, le=1000)


class NoticeCreateRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=1000)


# --------------------------------------------------------------- Student


class ApplicationCreateRequest(BaseModel):
    """A student's course application."""

    uid: str = Field(..., min_length=1, max_length=128)
    fullName: str = Field(..., min_length=2, max_length=100)
    cnic: str = Field(..., min_length=13, max_length=15)
    education: str = Field(..., min_length=1, max_length=60)
    city: str = Field(..., min_length=1, max_length=60)
    courseId: str = Field(..., min_length=1, max_length=128)
    courseName: str = Field(..., min_length=1, max_length=120)
    campusId: str = Field(..., min_length=1, max_length=128)
    campusName: str = Field(..., min_length=1, max_length=120)
    motivation: str = Field(..., min_length=20, max_length=2000)

    @field_validator("cnic")
    @classmethod
    def cnic_must_be_13_digits(cls, v: str) -> str:
        digits = "".join(ch for ch in v if ch.isdigit())
        if len(digits) != 13:
            raise ValueError("CNIC must contain exactly 13 digits")
        return v


class SubmissionCreateRequest(BaseModel):
    """Metadata for an assignment file already uploaded to Storage."""

    assignmentId: str = Field(..., min_length=1, max_length=128)
    uid: str = Field(..., min_length=1, max_length=128)
    textAnswer: str = Field(default="", max_length=5000)
    fileUrl: str = Field(default="", max_length=2000)
    fileName: str = Field(default="", max_length=255)

    @model_validator(mode="after")
    def needs_answer_or_file(self) -> "SubmissionCreateRequest":
        if not self.textAnswer.strip() and not self.fileUrl.strip():
            raise ValueError("Provide a text answer or a file URL")
        return self


# ------------------------------------------------------------ Instructor


class BulkAttendanceRequest(BaseModel):
    """One day's attendance for a whole batch."""

    batchId: str = Field(..., min_length=1, max_length=128)
    date: date
    statusMap: Dict[str, Literal["Present", "Absent", "Late"]] = Field(
        ..., min_length=1
    )

    @field_validator("statusMap")
    @classmethod
    def uids_must_be_sane(cls, v: Dict[str, str]) -> Dict[str, str]:
        for uid in v:
            if not uid or len(uid) > 128:
                raise ValueError(f"Invalid student uid: {uid!r}")
        return v


class GradeSubmissionRequest(BaseModel):
    """Marks and feedback for one submission."""

    submissionId: str = Field(..., min_length=1, max_length=256)
    marks: int = Field(..., ge=0, le=1000)
    feedback: str = Field(default="", max_length=2000)


# ----------------------------------------------------------- Coordinator


class BatchCreateRequest(BaseModel):
    """A new course batch."""

    batchCode: str = Field(..., min_length=3, max_length=40)
    courseId: str = Field(..., min_length=1, max_length=128)
    courseName: str = Field(..., min_length=1, max_length=120)
    campusId: str = Field(..., min_length=1, max_length=128)
    campusName: str = Field(..., min_length=1, max_length=120)
    instructorId: str = Field(default="", max_length=128)
    instructorName: str = Field(default="", max_length=120)
    maxSeats: int = Field(..., gt=0, le=500)
    startDate: date

    @field_validator("batchCode")
    @classmethod
    def code_is_slug_like(cls, v: str) -> str:
        code = v.strip().upper()
        if not all(ch.isalnum() or ch in "-_" for ch in code):
            raise ValueError(
                "Batch code may contain only letters, digits, - and _"
            )
        return code


class VerifyTokenRequest(BaseModel):
    """A Firebase ID token produced by the client after sign-in."""

    idToken: str = Field(..., min_length=10, max_length=8192)


class RegisterUserRequest(BaseModel):
    """A new account plus its Firestore profile."""

    email: str = Field(..., min_length=5, max_length=254)
    password: str = Field(..., min_length=6, max_length=128)
    name: str = Field(..., min_length=2, max_length=100)
    phone: str = Field(default="", max_length=20)
    role: Literal["student", "instructor", "coordinator"] = "student"
    city: str = Field(default="", max_length=60)
    campus: str = Field(default="", max_length=120)

    @field_validator("email")
    @classmethod
    def email_looks_valid(cls, v: str) -> str:
        value = v.strip().lower()
        if "@" not in value or "." not in value.split("@")[-1]:
            raise ValueError("Enter a valid email address")
        return value


class SetRoleRequest(BaseModel):
    """Change a user's role claim."""

    uid: str = Field(..., min_length=1, max_length=128)
    role: Literal["student", "instructor", "coordinator"]


class ApplicationStatusUpdateRequest(BaseModel):
    """Move an application to a new lifecycle state."""

    status: Literal[
        "Submitted",
        "Under Review",
        "Interview / Test",
        "Accepted",
        "Waiting List",
        "Rejected",
    ]
    rejectionReason: str = Field(default="", max_length=1000)

    @model_validator(mode="after")
    def reason_required_when_rejecting(
        self,
    ) -> "ApplicationStatusUpdateRequest":
        if self.status == "Rejected" and not self.rejectionReason.strip():
            raise ValueError("A rejection reason is required when rejecting")
        return self
