package com.institute.lms.exception;

/** The request was malformed or failed a business validation rule. Maps to 400. */
public class BadRequestException extends ApiException {

    public BadRequestException(String message) {
        super(ErrorCode.BAD_REQUEST, message);
    }

    public BadRequestException(ErrorCode code, String message) {
        super(code, message);
    }

    /** Convenience for field-level validation failures — names the offending field. */
    public static BadRequestException field(String field, String problem) {
        BadRequestException ex = new BadRequestException(ErrorCode.VALIDATION_FAILED,
                field + " " + problem);
        ex.detail("field", field);
        return ex;
    }
}
