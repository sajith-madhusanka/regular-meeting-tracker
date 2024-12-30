import ballerina/io;
import ballerina/time;
import ballerinax/googleapis.calendar;
import ballerinax/googleapis.docs;

// Configurable values for Google Calendar and Google Docs API authentication
configurable string CLIENT_ID = ?;
configurable string CLIENT_SECRET = ?;
configurable string REFRESH_TOKEN = ?;
configurable string REFRESH_URL = ?;

// Configurable calendar details and query parameters
configurable string CALENDAR_ID = "primary";
configurable string EVENT_TITLE = ?;
configurable string MIME_TYPE = ?;

// Initialize the Google Calendar API client configuration
calendar:ConnectionConfig config = {
    auth: {
        clientId: CLIENT_ID,
        clientSecret: CLIENT_SECRET,
        refreshToken: REFRESH_TOKEN,
        refreshUrl: REFRESH_URL
    }
};

// Initialize the Google Docs API client configuration
docs:ConnectionConfig connectionConfig = {
    auth: {
        clientId: CLIENT_ID,
        clientSecret: CLIENT_SECRET,
        refreshToken: REFRESH_TOKEN,
        refreshUrl: REFRESH_URL
    }
};

public function main() returns error? {
    // Create a new Google Calendar client
    calendar:Client|error calendarClient = check new(config);

    // Create a new Google Docs client
    docs:Client docsClient = check new(connectionConfig);

    // Calculate start and end times for event filtering (24 hours ahead)
    time:Utc startTime = time:utcAddSeconds(time:utcNow(), 86401);
    string timeMax = time:utcToString(startTime);
    time:Utc endTime = time:utcAddSeconds(time:utcNow(), 86400);
    string timeMin = time:utcToString(endTime);

    // Set up event filter criteria
    calendar:EventFilterCriteria criteria = {
        q: EVENT_TITLE,
        timeMax: timeMax,
        timeMin: timeMin
    };

    // Variables to hold the meeting note file URL and ID
    string meetingNoteFileUrl = "";
    string meetingNoteFileId = "";

    // Ensure the calendar client is valid
    if (calendarClient is calendar:Client) {
        // Log the filter criteria
        io:println("Fetching events with criteria: ", criteria);

        // Fetch events matching the criteria as a stream
        stream<calendar:Event, error?|error> response = check calendarClient->getEvents(CALENDAR_ID, criteria);

        // Process each event in the stream
        check response.forEach(function (calendar:Event event) {
            io:println("Processing event: ", event.summary);

            // Check if the event has attachments
            calendar:Attachment[]? attachments = event.attachments;
            if (attachments is calendar:Attachment[]) {
                io:println("Found ", attachments.length(), " attachment(s) for event: ", event.summary);

                // Process each attachment
                attachments.forEach(function (calendar:Attachment attachment) {
                    if (attachment.mimeType is string) {
                        string mimeType = <string>attachment.mimeType;

                        // Check if the MIME type matches the configured value
                        if (mimeType.equalsIgnoreCaseAscii(MIME_TYPE)) {
                            meetingNoteFileUrl = attachment.fileUrl;
                            meetingNoteFileId = <string>attachment.fileId;
                            io:println("Matching attachment found: ", meetingNoteFileUrl);
                            return; // Exit loop once the desired attachment is found
                        } else {
                            io:println("Attachment MIME type does not match: ", mimeType);
                        }
                    } else {
                        io:println("Attachment MIME type is null for event: ", event.summary);
                    }
                });
            } else {
                io:println("No attachments found for event: ", event.summary);
            }
        });

        // Log if no matching attachments were found
        if (meetingNoteFileUrl == "") {
            io:println("No matching attachments found for MIME type: ", MIME_TYPE);
        }
    } else {
        io:println("Error: Invalid calendar client configuration.");
    }

    // Log the URL of the desired meeting note file or indicate it was not found
    if (meetingNoteFileUrl != "") {
        io:println("Meeting note file URL: ", meetingNoteFileUrl);

        // Fetch and log the content of the meeting note file
        docs:Document|error docResponse = docsClient->getDocument(meetingNoteFileId);
        if (docResponse is docs:Document) {
            io:println("Retrieved document content successfully.");
            io:println("Document Content: ", docResponse.body);
        } else {
            io:println("Error: Failed to retrieve document. Error: ", docResponse.toString());
        }
    } else {
        io:println("No meeting note file URL found.");
    }
}