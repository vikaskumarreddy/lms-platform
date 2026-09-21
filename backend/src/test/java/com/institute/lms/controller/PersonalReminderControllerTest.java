package com.institute.lms.controller;

import com.institute.lms.entity.*;
import com.institute.lms.repository.PersonalReminderRepository;
import com.institute.lms.util.*;
import com.institute.lms.service.PersonalReminderScheduler;
import org.junit.jupiter.api.*;
import org.springframework.web.server.ResponseStatusException;
import java.time.Instant;
import java.util.Optional;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class PersonalReminderControllerTest {
    private final PersonalReminderRepository repository = mock(PersonalReminderRepository.class);
    private final UserContext users = mock(UserContext.class);
    private final OrganizationContext tenants = new OrganizationContext();
    private final PersonalReminderController controller = new PersonalReminderController(repository, users);
    @BeforeEach void setup() {
        Organization org = new Organization(); org.setId(3L); tenants.setCurrentOrganization(org);
        User user = new User(); user.setId(7L); user.setOrganizationId(3L);
        when(users.currentUser()).thenReturn(user);
        when(repository.save(any())).thenAnswer(i -> i.getArgument(0));
    }
    @AfterEach void clear() { tenants.clear(); }
    @Test void createStoresOwnerUtcAndInitialStatus() {
        var input = new PersonalReminderController.CreateReminder("  Revise  ", "Details",
                Instant.now().plusSeconds(3600), "+05:30");
        var saved = controller.create(input);
        assertEquals(7L, saved.getUserId()); assertEquals("Revise", saved.getTitle());
        assertEquals(input.dueAt(), saved.getDueAt());
        assertEquals("PENDING", saved.getStatus()); assertEquals("PENDING", saved.getNotificationStatus());
    }
    @Test void invalidTimeAndTitleRejected() {
        assertThrows(ResponseStatusException.class, () -> controller.create(
            new PersonalReminderController.CreateReminder("", "", Instant.now().plusSeconds(60), "UTC")));
        assertThrows(ResponseStatusException.class, () -> controller.create(
            new PersonalReminderController.CreateReminder("Title", "", Instant.now().minusSeconds(60), "UTC")));
        assertThrows(ResponseStatusException.class, () -> controller.create(
            new PersonalReminderController.CreateReminder("Title", "", Instant.now().plusSeconds(60), "invalid")));
        verify(repository, never()).save(any());
    }
    @Test void cannotAccessOtherOwners() {
        when(repository.findByIdAndUserId(9L, 7L)).thenReturn(Optional.empty());
        assertThrows(ResponseStatusException.class, () -> controller.status(9L,
            new PersonalReminderController.ChangeStatus("COMPLETED")));
        verify(repository, never()).save(any());
    }
    @Test void completionDoesNotInventNotificationDelivery() {
        var reminder = new PersonalReminder();
        when(repository.findByIdAndUserId(9L, 7L)).thenReturn(Optional.of(reminder));
        controller.status(9L, new PersonalReminderController.ChangeStatus("COMPLETED"));
        assertEquals("COMPLETED", reminder.getStatus());
        assertEquals("PENDING", reminder.getNotificationStatus());
        assertThrows(ResponseStatusException.class, () -> controller.status(9L,
            new PersonalReminderController.ChangeStatus("CANCELLED")));
    }
    @Test void missingSessionAndTenantRejected() {
        tenants.clear(); assertThrows(ResponseStatusException.class, controller::list);
        when(users.currentUser()).thenReturn(null);
        assertThrows(ResponseStatusException.class, controller::list);
        verifyNoInteractions(repository);
    }
    @Test void updateModifiesFieldsAndResetsStatusIfFuture() {
        var reminder = new PersonalReminder();
        reminder.setId(9L);
        reminder.setUserId(7L);
        reminder.setStatus("COMPLETED");
        when(repository.findByIdAndUserId(9L, 7L)).thenReturn(Optional.of(reminder));

        var futureTime = Instant.now().plusSeconds(7200);
        var input = new PersonalReminderController.CreateReminder("Updated Title", "Updated Desc", futureTime, "+05:30");
        var updated = controller.update(9L, input);

        assertEquals("Updated Title", updated.getTitle());
        assertEquals("Updated Desc", updated.getDescription());
        assertEquals("PENDING", updated.getStatus());
        assertEquals("PENDING", updated.getNotificationStatus());
        verify(repository).save(reminder);
    }

    @Test void deleteRemovesReminder() {
        var reminder = new PersonalReminder();
        reminder.setId(9L);
        reminder.setUserId(7L);
        when(repository.findByIdAndUserId(9L, 7L)).thenReturn(Optional.of(reminder));

        controller.delete(9L);
        verify(repository).delete(reminder);
    }
}
